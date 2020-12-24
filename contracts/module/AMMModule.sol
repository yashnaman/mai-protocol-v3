// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

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
        int256 squareValue; // 10^36
        int256 positionMargin;
        int256 availableCash;
        int256 position;
    }

    function queryTradeWithAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 tradeAmount,
        bool partialFill
    ) public view returns (int256 deltaCash, int256 deltaPosition) {
        require(tradeAmount != 0, "trade amount is zero");
        Context memory context = prepareContext(liquidityPool, perpetualIndex);
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        (int256 closeAmount, int256 openAmount) = Utils.splitAmount(context.position, tradeAmount);
        deltaCash = closePosition(perpetual, context, closeAmount);
        context.availableCash = context.availableCash.add(deltaCash);
        context.position = context.position.add(closeAmount);
        (int256 openDeltaMargin, int256 openDeltaPositionAmount) =
            openPosition(perpetual, context, openAmount, partialFill);
        deltaCash = deltaCash.add(openDeltaMargin);
        deltaPosition = closeAmount.add(openDeltaPositionAmount);
        if (deltaPosition < 0 && deltaCash < 0) {
            // negative price
            deltaCash = 0;
        }
        int256 halfSpread = perpetual.halfSpread.value.wmul(deltaCash);
        deltaCash = deltaCash > 0 ? deltaCash.add(halfSpread) : deltaCash.sub(halfSpread);
    }

    function getShareToMint(
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
            poolMargin = _getPoolMargin(liquidityPool).div(2);
        }
        context.availableCash = context.availableCash.add(cashToAdd);
        if (isAMMMarginSafe(context, 0)) {
            newPoolMargin = regress(context, 0);
        } else {
            newPoolMargin = _getPoolMargin(liquidityPool).add(cashToAdd).div(2);
        }
        if (poolMargin == 0) {
            require(shareTotalSupply == 0, "share has no value");
            shareToMint = newPoolMargin;
        } else {
            shareToMint = newPoolMargin.sub(poolMargin).wfrac(shareTotalSupply, poolMargin);
        }
    }

    function getCashToReturn(
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
        poolMargin = shareTotalSupply.sub(shareToRemove).wfrac(poolMargin, shareTotalSupply);
        {
            int256 minPoolMargin = context.squareValue.div(2).sqrt();
            require(poolMargin >= minPoolMargin, "amm is unsafe after removing liquidity");
        }
        cashToReturn = getMarginToRemove(context, poolMargin);
        require(cashToReturn >= 0, "received margin is negative");
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            require(
                perpetual.getPosition(address(this)) <=
                    poolMargin.wdiv(perpetual.openSlippageFactor.value),
                "amm is unsafe after removing liquidity"
            );
        }
        require(
            _getPoolMargin(liquidityPool).sub(cashToReturn) >= context.positionMargin,
            "amm exceeds max leverage after removing liquidity"
        );
    }

    function regress(Context memory context, int256 beta) public pure returns (int256 poolMargin) {
        int256 positionValue = context.indexPrice.wmul(context.position);
        int256 margin = positionValue.add(context.positionValue).add(context.availableCash);
        int256 tmp = positionValue.wmul(context.position).mul(beta).add(context.squareValue);
        int256 beforeSqrt = margin.mul(margin).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when regressing");
        poolMargin = beforeSqrt.sqrt().add(margin).div(2);
    }

    function isAMMMarginSafe(Context memory context, int256 beta) public pure returns (bool) {
        int256 value = context.indexPrice.wmul(context.position).add(context.positionValue);
        int256 minAvailableCash =
            context.indexPrice.wmul(context.position).wmul(context.position).mul(beta);
        minAvailableCash = minAvailableCash.add(context.squareValue).mul(2).sqrt().sub(value);
        return context.availableCash >= minAvailableCash;
    }

    function getPoolAvailableCash(LiquidityPoolStorage storage liquidityPool)
        internal
        view
        returns (int256 cash)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            cash = cash.add(perpetual.getAvailableCash(address(this)));
        }
        cash = cash.add(liquidityPool.poolCash);
    }

    function closePosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradeAmount
    ) public view returns (int256 deltaCash) {
        if (tradeAmount == 0) {
            return 0;
        }
        require(context.position != 0, "position is zero when close");
        int256 beta = perpetual.closeSlippageFactor.value;
        if (isAMMMarginSafe(context, beta)) {
            int256 poolMargin = regress(context, beta);
            require(poolMargin > 0, "pool margin must be positive");
            int256 newPositionAmount = context.position.add(tradeAmount);
            deltaCash = _getDeltaMargin(
                poolMargin,
                context.position,
                newPositionAmount,
                context.indexPrice,
                beta
            );
        } else {
            deltaCash = context.indexPrice.wmul(tradeAmount).neg();
        }
    }

    function openPosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradeAmount,
        bool partialFill
    ) private view returns (int256 deltaCash, int256 deltaPosition) {
        if (tradeAmount == 0) {
            return (0, 0);
        }
        int256 beta = perpetual.openSlippageFactor.value;
        if (!isAMMMarginSafe(context, beta)) {
            require(partialFill, "amm is unsafe when open");
            return (0, 0);
        }
        int256 newPosition = context.position.add(tradeAmount);
        require(newPosition != 0, "new position is zero when open");
        int256 poolMargin = regress(context, beta);
        require(poolMargin > 0, "pool margin must be positive");
        if (newPosition > 0) {
            int256 maxLongPosition =
                _getMaxPosition(context, poolMargin, perpetual.ammMaxLeverage.value, beta, true);
            if (newPosition > maxLongPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = maxLongPosition.sub(context.position);
                newPosition = maxLongPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        } else {
            int256 minShortPosition =
                _getMaxPosition(context, poolMargin, perpetual.ammMaxLeverage.value, beta, false);
            if (newPosition < minShortPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = minShortPosition.sub(context.position);
                newPosition = minShortPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        }
        deltaCash = _getDeltaMargin(
            poolMargin,
            context.position,
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

    /**
     * @param perpetualIndex. Set this value to perpetuals.length to skip distinguishing the current market from other markets.
     */
    function prepareContext(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        internal
        view
        returns (Context memory context)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            if (perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            int256 position = perpetual.getPosition(address(this));
            int256 indexPrice = perpetual.getIndexPrice();
            if (i == perpetualIndex) {
                context.indexPrice = indexPrice;
                context.position = position;
            } else {
                context.positionValue = context.positionValue.add(
                    indexPrice.wmul(position, Round.UP)
                );
                context.squareValue = context.squareValue.add(
                    indexPrice.wmul(position, Round.DOWN).wmul(position, Round.DOWN).mul(
                        perpetual.openSlippageFactor.value
                    )
                );
                context.positionMargin = context.positionMargin.add(
                    indexPrice.wmul(position).abs().wdiv(perpetual.ammMaxLeverage.value)
                );
            }
        }
        context.availableCash = getPoolAvailableCash(liquidityPool);
        require(
            context.availableCash.add(context.positionValue).add(
                context.indexPrice.wmul(context.position)
            ) >= 0,
            "amm is emergency"
        );
    }

    function getMarginToRemove(Context memory context, int256 poolMargin)
        public
        pure
        returns (int256 removingMargin)
    {
        if (poolMargin == 0) {
            return context.availableCash;
        }
        require(poolMargin > 0, "pool margin must be positive when removing liquidity");
        removingMargin = context.squareValue.div(poolMargin).div(2).add(poolMargin).sub(
            context.positionValue
        );
        removingMargin = context.availableCash.sub(removingMargin);
    }

    function _getDeltaMargin(
        int256 poolMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 beta
    ) internal pure returns (int256 deltaCash) {
        deltaCash = positionAmount2.add(positionAmount1).div(2).wfrac(beta, poolMargin);
        deltaCash = Constant.SIGNED_ONE.sub(deltaCash).wmul(indexPrice).wmul(
            positionAmount1.sub(positionAmount2)
        );
    }

    function _getMaxPosition(
        Context memory context,
        int256 poolMargin,
        int256 ammMaxLeverage,
        int256 beta,
        bool isLongSide
    ) internal pure returns (int256 maxPosition) {
        require(context.indexPrice > 0, "index price must be positive");
        int256 beforeSqrt =
            poolMargin
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
        beforeSqrt = beforeSqrt.wmul(ammMaxLeverage).wmul(ammMaxLeverage).wfrac(
            beta,
            context.indexPrice
        );
        beforeSqrt = poolMargin.sub(beforeSqrt.mul(2));
        if (beforeSqrt < 0) {
            maxPosition2 = type(int256).max;
        } else {
            maxPosition2 = beforeSqrt.mul(poolMargin).sqrt();
            maxPosition2 = poolMargin.sub(maxPosition2).wdiv(ammMaxLeverage).wdiv(beta);
        }
        maxPosition = maxPosition1.min(maxPosition2);
        if (isLongSide) {
            int256 maxPosition3 = poolMargin.wdiv(beta);
            maxPosition = maxPosition.min(maxPosition3);
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    function _getPoolMargin(LiquidityPoolStorage storage liquidityPool)
        private
        view
        returns (int256 marginBalance)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            if (perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            marginBalance = marginBalance.add(
                perpetual.getMargin(address(this), perpetual.getIndexPrice())
            );
        }
        marginBalance = marginBalance.add(liquidityPool.poolCash);
    }
}
