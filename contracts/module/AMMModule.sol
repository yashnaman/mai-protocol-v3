// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

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
    using OracleModule for PerpetualStorage;
    using MarginModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;

    struct Context {
        int256 indexPrice;
        int256 positionValue;
        int256 squareValue;
        int256 positionMargin;
        int256 availableCashBalance;
        int256 positionAmount;
    }

    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);

    function tradeWithAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 tradingAmount,
        bool partialFill
    ) public view returns (int256 deltaMargin, int256 deltaPosition) {
        require(tradingAmount != 0, "trade amount is zero");
        Context memory context = prepareContext(liquidityPool, perpetualIndex);
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        (int256 closingAmount, int256 openingAmount) = Utils.splitAmount(
            context.positionAmount,
            tradingAmount
        );
        deltaMargin = closePosition(perpetual, context, closingAmount);
        context.availableCashBalance = context.availableCashBalance.add(deltaMargin);
        context.positionAmount = context.positionAmount.add(closingAmount);
        (int256 openDeltaMargin, int256 openDeltaPosition) = openPosition(
            perpetual,
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
        int256 halfSpread = perpetual.halfSpread.value.wmul(deltaMargin);
        deltaMargin = deltaMargin > 0 ? deltaMargin.add(halfSpread) : deltaMargin.sub(halfSpread);
    }

    function addLiquidity(LiquidityPoolStorage storage liquidityPool, int256 cashAmount) public {
        int256 totalCashAmount = liquidityPool.transferFromUser(msg.sender, cashAmount);
        require(totalCashAmount > 0, "total cashAmount must be positive");
        int256 shareTotalSupply = IERC20Upgradeable(liquidityPool.shareToken)
            .totalSupply()
            .toInt256();
        int256 shareAmount = calculateShareToMint(liquidityPool, shareTotalSupply, totalCashAmount);
        require(shareAmount > 0, "received share must be positive");
        liquidityPool.poolCashBalance = liquidityPool.poolCashBalance.add(totalCashAmount);
        liquidityPool.poolCollateral = liquidityPool.poolCollateral.add(totalCashAmount);
        IShareToken(liquidityPool.shareToken).mint(msg.sender, shareAmount.toUint256());
        emit AddLiquidity(msg.sender, totalCashAmount, shareAmount);
    }

    function calculateShareToMint(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 cashToAdd
    ) internal view returns (int256 shareToMint) {
        Context memory context = prepareContext(liquidityPool);
        int256 poolMargin;
        int256 newPoolMargin;
        if (isAMMMarginSafe(context, 0)) {
            poolMargin = regress(context, 0);
        } else {
            poolMargin = poolMarginBalance(liquidityPool).div(2);
        }
        context.availableCashBalance = context.availableCashBalance.add(cashToAdd);
        if (isAMMMarginSafe(context, 0)) {
            newPoolMargin = regress(context, 0);
        } else {
            newPoolMargin = poolMarginBalance(liquidityPool).add(cashToAdd).div(2);
        }
        if (poolMargin == 0) {
            require(shareTotalSupply == 0, "share has no value");
            shareToMint = newPoolMargin;
        } else {
            shareToMint = newPoolMargin.sub(poolMargin).wfrac(shareTotalSupply, poolMargin);
        }
    }

    function removeLiquidity(LiquidityPoolStorage storage liquidityPool, int256 shareToRemove)
        public
    {
        require(shareToRemove > 0, "share to remove must be positive");
        require(
            shareToRemove <=
                IERC20Upgradeable(liquidityPool.shareToken).balanceOf(msg.sender).toInt256(),
            "insufficient share balance"
        );
        int256 shareTotalSupply = IERC20Upgradeable(liquidityPool.shareToken)
            .totalSupply()
            .toInt256();
        int256 cashToReturn = calculateCashToReturn(liquidityPool, shareTotalSupply, shareToRemove);
        IShareToken(liquidityPool.shareToken).burn(msg.sender, shareToRemove.toUint256());
        liquidityPool.poolCashBalance = liquidityPool.poolCashBalance.sub(cashToReturn);
        liquidityPool.poolCollateral = liquidityPool.poolCollateral.sub(cashToReturn);
        liquidityPool.transferToUser(payable(msg.sender), cashToReturn);
        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    function calculateCashToReturn(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 shareToRemove
    ) public view returns (int256 cashToReturn) {
        Context memory context = prepareContext(liquidityPool);
        require(isAMMMarginSafe(context, 0), "amm is unsafe before removing liquidity");
        int256 poolMargin = regress(context, 0);
        if (poolMargin == 0) {
            return 0;
        }
        {
            poolMargin = shareTotalSupply.sub(shareToRemove).wfrac(poolMargin, shareTotalSupply);
            int256 minPoolMargin = context.squareValue.div(2).sqrt();
            require(poolMargin >= minPoolMargin, "amm is unsafe after removing liquidity");
        }
        cashToReturn = marginToRemove(context, poolMargin);
        require(cashToReturn >= 0, "received margin is negative");
        int256 newMarginBalance = poolMarginBalance(liquidityPool).sub(cashToReturn);
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            require(
                perpetual.positionAmount(address(this)) <=
                    poolMargin.wdiv(perpetual.openSlippageFactor.value),
                "amm is unsafe after removing liquidity"
            );
        }
        require(
            newMarginBalance >= context.positionMargin,
            "amm exceeds max leverage after removing liquidity"
        );
    }

    function regress(Context memory context, int256 beta) public pure returns (int256 poolMargin) {
        int256 positionValue = context.indexPrice.wmul(context.positionAmount);
        int256 marginBalance = positionValue.add(context.positionValue).add(
            context.availableCashBalance
        );
        int256 tmp = positionValue.wmul(context.positionAmount).mul(beta).add(context.squareValue);
        int256 beforeSqrt = marginBalance.mul(marginBalance).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when regressing");
        poolMargin = beforeSqrt.sqrt().add(marginBalance).div(2);
    }

    function isAMMMarginSafe(Context memory context, int256 beta) public pure returns (bool) {
        int256 value = context.indexPrice.wmul(context.positionAmount).add(context.positionValue);
        int256 minAvailableCashBalance = context
            .indexPrice
            .wmul(context.positionAmount)
            .wmul(context.positionAmount)
            .mul(beta);
        minAvailableCashBalance = minAvailableCashBalance
            .add(context.squareValue)
            .mul(2)
            .sqrt()
            .sub(value);
        return context.availableCashBalance >= minAvailableCashBalance;
    }

    function poolCashBalance(LiquidityPoolStorage storage liquidityPool)
        internal
        view
        returns (int256 cashBalance)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            cashBalance = cashBalance.add(perpetual.availableCashBalance(address(this)));
        }
        cashBalance = cashBalance.add(liquidityPool.poolCashBalance);
    }

    function closePosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradingAmount
    ) public view returns (int256 deltaMargin) {
        if (tradingAmount == 0) {
            return 0;
        }
        require(context.positionAmount != 0, "position is zero when close");
        int256 beta = perpetual.closeSlippageFactor.value;
        if (isAMMMarginSafe(context, beta)) {
            int256 poolMargin = regress(context, beta);
            require(poolMargin > 0, "pool margin must be positive");
            int256 newPositionAmount = context.positionAmount.add(tradingAmount);
            deltaMargin = _deltaMargin(
                poolMargin,
                context.positionAmount,
                newPositionAmount,
                context.indexPrice,
                beta
            );
        } else {
            deltaMargin = context.indexPrice.wmul(tradingAmount).neg();
        }
    }

    function openPosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradingAmount,
        bool partialFill
    ) private view returns (int256 deltaMargin, int256 deltaPosition) {
        if (tradingAmount == 0) {
            return (0, 0);
        }
        int256 beta = perpetual.openSlippageFactor.value;
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
                perpetual.maxLeverage.value,
                beta,
                true
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
                perpetual.maxLeverage.value,
                beta,
                false
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

    function prepareContext(LiquidityPoolStorage storage liquidityPool)
        internal
        view
        returns (Context memory context)
    {
        return prepareContext(liquidityPool, liquidityPool.perpetuals.length);
    }

    function prepareContext(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        internal
        view
        returns (Context memory context)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            int256 positionAmount = perpetual.positionAmount(address(this));
            int256 indexPrice = perpetual.indexPrice();
            if (i == perpetualIndex) {
                context.indexPrice = indexPrice;
                context.positionAmount = positionAmount;
            } else {
                context.positionValue = context.positionValue.add(
                    indexPrice.wmul(positionAmount, Round.UP)
                );
                context.squareValue = context.squareValue.add(
                    indexPrice
                        .wmul(positionAmount, Round.DOWN)
                        .wmul(positionAmount, Round.DOWN)
                        .mul(perpetual.openSlippageFactor.value)
                );
                context.positionMargin = context.positionMargin.add(
                    indexPrice.wmul(positionAmount).abs().wdiv(perpetual.maxLeverage.value)
                );
            }
        }
        context.availableCashBalance = poolCashBalance(liquidityPool);
        require(
            context.availableCashBalance.add(context.positionValue).add(
                context.indexPrice.wmul(context.positionAmount)
            ) >= 0,
            "amm is emergency"
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
        bool isLongSide
    ) internal pure returns (int256 maxPosition) {
        require(context.indexPrice > 0, "index price must be positive");
        int256 beforeSqrt = poolMargin
            .mul(poolMargin)
            .mul(2)
            .sub(context.squareValue)
            .wdiv(context.indexPrice)
            .wdiv(beta);
        if (beforeSqrt <= 0) {
            return 0;
        }
        int256 maxPosition1 = beforeSqrt.sqrt();
        int256 maxPosition2;
        beforeSqrt = poolMargin.sub(context.positionMargin).add(
            context.squareValue.div(poolMargin).div(2)
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
        if (isLongSide) {
            int256 maxPosition3 = poolMargin.wdiv(beta);
            maxPosition = maxPosition > maxPosition3 ? maxPosition3 : maxPosition;
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    function poolMarginBalance(LiquidityPoolStorage storage liquidityPool)
        private
        view
        returns (int256 marginBalance)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            marginBalance = marginBalance.add(
                perpetual.margin(address(this), perpetual.indexPrice())
            );
        }
        marginBalance = marginBalance.add(liquidityPool.poolCashBalance);
    }

    function marginToRemove(Context memory context, int256 poolMargin)
        public
        pure
        returns (int256 removingMargin)
    {
        if (poolMargin == 0) {
            return context.availableCashBalance;
        }
        require(poolMargin > 0, "pool margin must be positive when removing liquidity");
        removingMargin = context.squareValue.div(poolMargin).div(2).add(poolMargin).sub(
            context.positionValue
        );
        removingMargin = context.availableCashBalance.sub(removingMargin);
    }
}
