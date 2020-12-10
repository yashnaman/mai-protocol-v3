// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../interface/IShareToken.sol";

import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../module/CollateralModule.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";

import "../Type.sol";

library AMMModule {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using SafeMathUpgradeable for uint256;
    using OracleModule for Market;
    using MarginModule for Market;
    using CollateralModule for Core;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    struct Context {
        int256 indexPrice;
        int256 IntermediateValue1;
        int256 IntermediateValue2;
        int256 IntermediateValue3;
        int256 availableCashBalance;
        int256 positionAmount;
    }

    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);

    function tradeWithAMM(
        Core storage core,
        uint256 marketIndex,
        int256 tradingAmount,
        bool partialFill
    ) public view returns (int256 deltaMargin, int256 deltaPosition) {
        require(tradingAmount != 0, "trade amount is zero");
        Market storage market = core.markets[marketIndex];
        Context memory context = prepareContext(core, market);
        (int256 closingAmount, int256 openingAmount) = Utils.splitAmount(
            context.positionAmount,
            tradingAmount
        );
        deltaMargin = closePosition(market, context, closingAmount);
        context.availableCashBalance = context.availableCashBalance.add(deltaMargin);
        context.positionAmount = context.positionAmount.add(closingAmount);
        (int256 openDeltaMargin, int256 openDeltaPosition) = openPosition(
            market,
            context,
            openingAmount,
            partialFill
        );
        deltaMargin = deltaMargin.add(openDeltaMargin);
        deltaPosition = closingAmount.add(openDeltaPosition);
        if (deltaPosition < 0 && deltaMargin < 0) {
            // negative price
            deltaMargin = 0;
        }
        int256 halfSpread = market.halfSpread.value.wmul(deltaMargin);
        deltaMargin = deltaMargin > 0 ? deltaMargin.add(halfSpread) : deltaMargin.sub(halfSpread);
    }

    function addLiquidity(
        Core storage core,
        uint256 marketIndex,
        int256 cashAmount
    ) public {
        require(cashAmount > 0, "margin to add must be positive");
        int256 shareAmount = calculateShareToMint(core, marketIndex, cashAmount);
        require(shareAmount > 0, "received share must be positive");
        core.transferFromUser(msg.sender, cashAmount);
        IShareToken(core.shareToken).mint(msg.sender, shareAmount.toUint256());
        emit AddLiquidity(msg.sender, cashAmount, shareAmount);
    }

    function calculateShareToMint(
        Core storage core,
        uint256 marketIndex,
        int256 cashToAdd
    ) internal view returns (int256 shareToMint) {
        Market storage market = core.markets[marketIndex];
        Context memory context = prepareContext(core, market);
        int256 beta = market.openSlippageFactor.value;
        int256 poolMargin;
        int256 newPoolMargin;
        if (isAMMMarginSafe(context, beta)) {
            poolMargin = regress(context, beta);
        } else {
            poolMargin = poolMarginBalance(core).div(2);
        }
        context.availableCashBalance = context.availableCashBalance.add(cashToAdd);
        if (isAMMMarginSafe(context, beta)) {
            newPoolMargin = regress(context, beta);
        } else {
            newPoolMargin = poolMarginBalance(core).add(cashToAdd).div(2);
        }
        int256 shareTotalSupply = IERC20Upgradeable(core.shareToken).totalSupply().toInt256();
        if (poolMargin == 0) {
            require(shareTotalSupply == 0, "share has no value");
            shareToMint = newPoolMargin;
        } else {
            shareToMint = newPoolMargin.sub(poolMargin).wfrac(shareTotalSupply, poolMargin);
        }
    }

    function removeLiquidity(
        Core storage core,
        uint256 marketIndex,
        int256 shareToRemove
    ) public {
        require(shareToRemove > 0, "share to remove must be positive");
        require(
            shareToRemove <= IERC20Upgradeable(core.shareToken).balanceOf(msg.sender).toInt256(),
            "insufficient share balance"
        );
        int256 cashToReturn = calculateCashToReturn(core, marketIndex, shareToRemove);
        IShareToken(core.shareToken).burn(msg.sender, shareToRemove.toUint256());
        core.transferToUser(payable(msg.sender), cashToReturn);
        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    function calculateCashToReturn(
        Core storage core,
        uint256 marketIndex,
        int256 shareToRemove
    ) public view returns (int256 cashToReturn) {
        Market storage market = core.markets[marketIndex];
        Context memory context = prepareContext(core, market);
        int256 beta = market.openSlippageFactor.value;
        int256 positionAmount = context.positionAmount;
        require(isAMMMarginSafe(context, beta), "amm is unsafe before removing liquidity");
        int256 poolMargin = regress(context, beta);
        if (poolMargin == 0) {
            return 0;
        }
        {
            int256 shareTotalSupply = IERC20Upgradeable(core.shareToken).totalSupply().toInt256();
            poolMargin = shareTotalSupply.sub(shareToRemove).wfrac(poolMargin, shareTotalSupply);
            int256 minPoolMargin = context.indexPrice.wmul(positionAmount).wmul(positionAmount);
            minPoolMargin = minPoolMargin.mul(beta).add(context.IntermediateValue2).div(2).sqrt();
            require(
                poolMargin >= minPoolMargin && positionAmount <= poolMargin.wdiv(beta),
                "amm is unsafe after removing liquidity"
            );
        }
        cashToReturn = marginToRemove(context, poolMargin, beta);
        require(cashToReturn >= 0, "received margin is negative");
        int256 newMarginBalance = poolMarginBalance(core).sub(cashToReturn);
        int256 positionValue = context
            .indexPrice
            .wfrac(positionAmount.abs(), market.maxLeverage.value)
            .add(context.IntermediateValue3);
        require(
            newMarginBalance >= positionValue,
            "amm exceeds max leverage after removing liquidity"
        );
    }

    function regress(Context memory context, int256 beta) public pure returns (int256 poolMargin) {
        int256 positionValue = context.indexPrice.wmul(context.positionAmount);
        int256 marginBalance = positionValue.add(context.IntermediateValue1);
        int256 tmp = positionValue.wmul(context.positionAmount).mul(beta).add(
            context.IntermediateValue2
        );
        int256 beforeSqrt = marginBalance.mul(marginBalance).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when regressing");
        poolMargin = beforeSqrt.sqrt().add(marginBalance).div(2);
    }

    function isAMMMarginSafe(Context memory context, int256 beta) public pure returns (bool) {
        int256 partialMarginBalance = context.availableCashBalance.add(context.IntermediateValue1);
        int256 betaPos = beta.wmul(context.positionAmount);
        if (context.positionAmount == 0) {
            return
                partialMarginBalance.mul(partialMarginBalance).sub(
                    context.IntermediateValue2.mul(2)
                ) >= 0;
        }
        int256 beforeSqrt = partialMarginBalance.mul(2).neg().add(betaPos).mul(betaPos).add(
            context.IntermediateValue2.mul(2)
        );
        if (context.positionAmount > 0 && beforeSqrt < 0) {
            return true;
        }
        require(beforeSqrt >= 0, "index bound is invalid");
        int256 bound = beforeSqrt.sqrt().add(betaPos).sub(partialMarginBalance).wdiv(
            context.positionAmount
        );
        return
            context.positionAmount > 0 ? context.indexPrice >= bound : context.indexPrice <= bound;
    }

    function liquidityPoolCashBalance(Core storage core)
        internal
        view
        returns (int256 cashBalance)
    {
        uint256 length = core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            Market storage market = core.markets[i];
            cashBalance = cashBalance.add(market.availableCashBalance(address(this)));
        }
        cashBalance = cashBalance.add(core.liquidityPoolCashBalance);
    }

    function prepareContext(Core storage core, Market storage currentMarket)
        internal
        view
        returns (Context memory context)
    {
        uint256 length = core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            Market storage market = core.markets[i];
            int256 positionAmount = market.positionAmount(address(this));
            int256 indexPrice = market.indexPrice();
            if (market.id == currentMarket.id) {
                context.indexPrice = indexPrice;
                context.positionAmount = positionAmount;
            } else {
                int256 positionValue = indexPrice.wmul(positionAmount);
                context.IntermediateValue1 = context.IntermediateValue1.add(positionValue);
                context.IntermediateValue2 = context.IntermediateValue2.add(
                    positionValue.wmul(positionAmount).mul(market.openSlippageFactor.value)
                );
                context.IntermediateValue3 = context.IntermediateValue3.add(
                    positionValue.abs().wdiv(market.maxLeverage.value)
                );
            }
        }
        context.availableCashBalance = liquidityPoolCashBalance(core);
        require(
            context.availableCashBalance.add(context.IntermediateValue1).add(
                context.indexPrice.wmul(context.positionAmount)
            ) >= 0,
            "amm is emergency"
        );
    }

    function closePosition(
        Market storage market,
        Context memory context,
        int256 tradingAmount
    ) public view returns (int256 deltaMargin) {
        if (tradingAmount == 0) {
            return 0;
        }
        require(context.positionAmount != 0, "position is zero when close");
        int256 beta = market.closeSlippageFactor.value;
        if (isAMMMarginSafe(context, beta)) {
            int256 poolMargin = regress(context, beta);
            require(poolMargin > 0, "pool margin must be positive");
            int256 newPositionAmount = context.positionAmount.add(tradingAmount);
            if (newPositionAmount == 0) {
                return poolMargin.sub(context.availableCashBalance);
            } else {
                deltaMargin = _deltaMargin(
                    poolMargin,
                    context.positionAmount,
                    newPositionAmount,
                    context.indexPrice,
                    beta
                );
            }
        } else {
            deltaMargin = context.indexPrice.wmul(tradingAmount).neg();
        }
    }

    function openPosition(
        Market storage market,
        Context memory context,
        int256 tradingAmount,
        bool partialFill
    ) private view returns (int256 deltaMargin, int256 deltaPosition) {
        if (tradingAmount == 0) {
            return (0, 0);
        }
        int256 beta = market.openSlippageFactor.value;
        if (!isAMMMarginSafe(context, beta)) {
            require(partialFill, "amm is unsafe when open");
            return (0, 0);
        }
        int256 newPosition = context.positionAmount.add(tradingAmount);
        require(newPosition != 0, "new position is zero when open");
        int256 poolMargin = regress(context, beta);
        require(poolMargin > 0, "pool margin must be positive");
        if (newPosition > 0) {
            int256 maxLongPosition = _maxPosition(
                context,
                poolMargin,
                market.maxLeverage.value,
                beta,
                Side.LONG
            );
            if (newPosition > maxLongPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = maxLongPosition.sub(context.positionAmount);
                newPosition = maxLongPosition;
            } else {
                deltaPosition = tradingAmount;
            }
        } else {
            int256 minShortPosition = _maxPosition(
                context,
                poolMargin,
                market.maxLeverage.value,
                beta,
                Side.SHORT
            );
            if (newPosition < minShortPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = minShortPosition.sub(context.positionAmount);
                newPosition = minShortPosition;
            } else {
                deltaPosition = tradingAmount;
            }
        }
        deltaMargin = _deltaMargin(
            poolMargin,
            context.positionAmount,
            newPosition,
            context.indexPrice,
            beta
        );
    }

    function _deltaMargin(
        int256 poolMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 beta
    ) internal pure returns (int256 deltaMargin) {
        deltaMargin = positionAmount2.add(positionAmount1).div(2).wfrac(beta, poolMargin).neg();
        deltaMargin = deltaMargin.add(Constant.SIGNED_ONE).wmul(indexPrice).wmul(
            positionAmount1.sub(positionAmount2)
        );
    }

    function _maxPosition(
        Context memory context,
        int256 poolMargin,
        int256 maxLeverage,
        int256 beta,
        Side side
    ) internal pure returns (int256 maxPosition) {
        require(context.indexPrice > 0, "index price must be positive");
        int256 beforeSqrt = poolMargin
            .mul(poolMargin)
            .mul(2)
            .sub(context.IntermediateValue2)
            .wdiv(context.indexPrice)
            .wdiv(beta);
        int256 maxPosition1 = beforeSqrt < 0 ? 0 : beforeSqrt.sqrt();
        int256 maxPosition2;
        beforeSqrt = poolMargin.sub(context.IntermediateValue3).add(
            context.IntermediateValue2.div(poolMargin).div(2)
        );
        beforeSqrt = beforeSqrt.wmul(maxLeverage).wmul(maxLeverage).wmul(beta);
        beforeSqrt = poolMargin.sub(beforeSqrt.mul(2).wdiv(context.indexPrice));
        if (beforeSqrt < 0) {
            maxPosition2 = type(int256).max;
        } else {
            maxPosition2 = beforeSqrt.mul(poolMargin).sqrt();
            maxPosition2 = poolMargin.sub(maxPosition2).wdiv(maxLeverage).wdiv(beta);
        }
        maxPosition = maxPosition1 > maxPosition2 ? maxPosition2 : maxPosition1;
        if (side == Side.LONG) {
            int256 maxPosition3 = poolMargin.wdiv(beta);
            maxPosition = maxPosition > maxPosition3 ? maxPosition3 : maxPosition;
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    function poolMarginBalance(Core storage core) private view returns (int256 marginBalance) {
        uint256 length = core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            Market storage market = core.markets[i];
            marginBalance = marginBalance.add(market.margin(address(this)));
        }
        marginBalance = marginBalance.add(core.liquidityPoolCashBalance);
    }

    function marginToRemove(
        Context memory context,
        int256 poolMargin,
        int256 beta
    ) public pure returns (int256 removingMargin) {
        if (poolMargin == 0) {
            return context.availableCashBalance;
        }
        int256 positionValue = context.indexPrice.wmul(context.positionAmount);
        int256 tmpA = context.IntermediateValue1.add(positionValue);
        int256 tmpB = context.IntermediateValue2.add(
            positionValue.wmul(context.positionAmount).mul(beta)
        );
        removingMargin = tmpB.div(poolMargin).div(2).add(poolMargin).sub(tmpA);
        removingMargin = context.availableCashBalance.sub(removingMargin);
    }
}
