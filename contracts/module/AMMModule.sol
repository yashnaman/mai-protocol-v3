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

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";

import "../Type.sol";

library AMMModule {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using SafeMathUpgradeable for uint256;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

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
        int256 halfSpread = perpetual.halfSpread.value;
        if (tradeAmount > 0) {
            halfSpread = halfSpread.neg();
        }
        (int256 closeAmount, int256 openAmount) = Utils.splitAmount(context.position, tradeAmount);
        int256 closeMidPrice;
        (deltaCash, closeMidPrice) = closePosition(perpetual, context, closeAmount);
        context.availableCash = context.availableCash.add(deltaCash);
        context.position = context.position.add(closeAmount);
        (int256 openDeltaMargin, int256 openDeltaPositionAmount, int256 openMidPrice) = openPosition(perpetual, context, openAmount, partialFill);
        deltaCash = deltaCash.add(openDeltaMargin);
        deltaPosition = closeAmount.add(openDeltaPositionAmount);
        if (deltaPosition < 0 && deltaCash < 0) {
            // negative price
            deltaCash = 0;
        }
        int256 midPrice = closeAmount != 0 ? closeMidPrice : openMidPrice;
        int256 deltaCashAtBestPrice = midPrice.wmul(halfSpread.add(Constant.SIGNED_ONE)).wmul(deltaPosition).neg();
        deltaCash = deltaCash.max(deltaCashAtBestPrice);
    }

    function getShareToMint(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 cashToAdd
    ) internal view returns (int256 shareToMint) {
        Context memory context = prepareContext(liquidityPool);
        (int256 poolMargin, ) = getPoolMargin(context);
        context.availableCash = context.availableCash.add(cashToAdd);
        (int256 newPoolMargin, ) = getPoolMargin(context);
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
            if (perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            require(
                perpetual.getPosition(address(this)) <=
                    poolMargin.wdiv(perpetual.openSlippageFactor.value),
                "amm is unsafe after removing liquidity"
            );
        }
        require(
            context.availableCash.add(context.positionValue).sub(cashToReturn) >=
                context.positionMargin,
            "amm exceeds max leverage after removing liquidity"
        );
    }

    function regress(Context memory context, int256 slippageFactor)
        public
        pure
        returns (int256 poolMargin)
    {
        int256 positionValue = context.indexPrice.wmul(context.position);
        int256 margin = positionValue.add(context.positionValue).add(context.availableCash);
        int256 tmp = positionValue.wmul(context.position).mul(slippageFactor).add(
            context.squareValue
        );
        int256 beforeSqrt = margin.mul(margin).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when regressing");
        poolMargin = beforeSqrt.sqrt().add(margin).div(2);
    }

    function isAMMMarginSafe(Context memory context, int256 slippageFactor)
        public
        pure
        returns (bool)
    {
        int256 value = context.indexPrice.wmul(context.position).add(context.positionValue);
        int256 minAvailableCash = context
            .indexPrice
            .wmul(context.position)
            .wmul(context.position)
            .mul(slippageFactor);
        minAvailableCash = minAvailableCash.add(context.squareValue).mul(2).sqrt().sub(value);
        return context.availableCash >= minAvailableCash;
    }

    function closePosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradeAmount
    ) public view returns (int256 deltaCash, int256 midPrice) {
        if (tradeAmount == 0) {
            return (0, 0);
        }
        int256 positionBefore = context.position;
        require(positionBefore != 0, "position is zero when close");
        int256 slippageFactor = perpetual.closeSlippageFactor.value;
        if (isAMMMarginSafe(context, slippageFactor)) {
            int256 poolMargin = regress(context, slippageFactor);
            require(poolMargin > 0, "pool margin must be positive");
            midPrice = _getPrice(context.indexPrice, poolMargin, positionBefore, slippageFactor);
            deltaCash = _getDeltaMargin(
                poolMargin,
                positionBefore,
                positionBefore.add(tradeAmount),
                context.indexPrice,
                slippageFactor
            );
        } else {
            midPrice = context.indexPrice;
            deltaCash = context
                .indexPrice
                .wmul(tradeAmount)
                .neg();
        }
    }

    function openPosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradeAmount,
        bool partialFill
    ) private view returns (int256 deltaCash, int256 deltaPosition, int256 midPrice) {
        if (tradeAmount == 0) {
            return (0, 0, 0);
        }
        int256 positionBefore = context.position;
        int256 positionAfter = positionBefore.add(tradeAmount);
        require(positionAfter != 0, "after position is zero when open");
        int256 slippageFactor = perpetual.openSlippageFactor.value;
        if (!isAMMMarginSafe(context, slippageFactor)) {
            require(partialFill, "amm is unsafe when open");
            return (0, 0, 0);
        }
        int256 poolMargin = regress(context, slippageFactor);
        require(poolMargin > 0, "pool margin must be positive");
        int256 indexPrice = context.indexPrice;
        midPrice = _getPrice(indexPrice, poolMargin, positionBefore, slippageFactor);
        int256 ammMaxLeverage = perpetual.ammMaxLeverage.value;
        if (positionAfter > 0) {
            int256 maxLongPosition = _getMaxPosition(
                context,
                poolMargin,
                ammMaxLeverage,
                slippageFactor,
                true
            );
            if (positionAfter > maxLongPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = maxLongPosition.sub(positionBefore);
                positionAfter = maxLongPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        } else {
            int256 minShortPosition = _getMaxPosition(
                context,
                poolMargin,
                ammMaxLeverage,
                slippageFactor,
                false
            );
            if (positionAfter < minShortPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = minShortPosition.sub(positionBefore);
                positionAfter = minShortPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        }
        deltaCash =  _getDeltaMargin(poolMargin, positionBefore, positionAfter, indexPrice, slippageFactor);
        require(!Utils.hasTheSameSign(deltaCash, tradeAmount), "invalid delta cash");
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
            context.availableCash = context.availableCash.add(
                perpetual.getAvailableCash(address(this))
            );
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
        context.availableCash = context.availableCash.add(liquidityPool.poolCash);
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

    function _getPrice(
        int256 indexPrice,
        int256 poolMargin,
        int256 position,
        int256 slippageFactor
    ) internal pure returns (int256) {
        return Constant.SIGNED_ONE.sub(position.wfrac(slippageFactor, poolMargin)).wmul(indexPrice);
    }

    function _getDeltaMargin(
        int256 poolMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 slippageFactor
    ) internal pure returns (int256 deltaCash) {
        deltaCash = positionAmount2.add(positionAmount1).div(2).wfrac(slippageFactor, poolMargin);
        deltaCash = Constant.SIGNED_ONE.sub(deltaCash).wmul(indexPrice).wmul(
            positionAmount1.sub(positionAmount2)
        );
    }

    function _getMaxPosition(
        Context memory context,
        int256 poolMargin,
        int256 ammMaxLeverage,
        int256 slippageFactor,
        bool isLongSide
    ) internal pure returns (int256 maxPosition) {
        require(context.indexPrice > 0, "index price must be positive");
        int256 beforeSqrt = poolMargin
            .mul(poolMargin)
            .mul(2)
            .sub(context.squareValue)
            .wdiv(context.indexPrice)
            .wdiv(slippageFactor);
        if (beforeSqrt <= 0) {
            return 0;
        }
        int256 maxPosition1 = beforeSqrt.sqrt();
        int256 maxPosition2;
        beforeSqrt = poolMargin.sub(context.positionMargin).add(
            context.squareValue.div(poolMargin).div(2)
        );
        beforeSqrt = beforeSqrt.wmul(ammMaxLeverage).wmul(ammMaxLeverage).wfrac(
            slippageFactor,
            context.indexPrice
        );
        beforeSqrt = poolMargin.sub(beforeSqrt.mul(2));
        if (beforeSqrt < 0) {
            maxPosition2 = type(int256).max;
        } else {
            maxPosition2 = beforeSqrt.mul(poolMargin).sqrt();
            maxPosition2 = poolMargin.sub(maxPosition2).wdiv(ammMaxLeverage).wdiv(slippageFactor);
        }
        maxPosition = maxPosition1.min(maxPosition2);
        if (isLongSide) {
            int256 maxPosition3 = poolMargin.wdiv(slippageFactor);
            maxPosition = maxPosition.min(maxPosition3);
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    function getPoolMargin(Context memory context) internal pure returns (int256, bool) {
        if (isAMMMarginSafe(context, 0)) {
            return (regress(context, 0), true);
        } else {
            return (context.availableCash.add(context.positionValue).div(2), false);
        }
    }
}
