// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";

import "../Type.sol";

/**
 * @title Mai3 AMM implementation
 */
library AMMModule {

    using Math for int256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    struct Context {
        int256 indexPrice;
        int256 position;
        int256 positionValue;
        // this is 10^36, others are 10^18
        int256 squareValue;
        int256 positionMargin;
        int256 availableCash;
    }

    /**
     * @dev Get the result when trading with amm
     * @param liquidityPool The liquidity pool of amm
     * @param perpetualIndex The index of the perpetual to trade
     * @param tradeAmount The trading amount, positive if amm longs, negative if amm shorts
     * @param partialFill Whether to allow partial trading, set to true when liquidation trading,
              set to false when normal trading
     * @return deltaCash The trading cash result, positive when amm's cash increases,
               negative when amm's cash decrease
     * @return deltaPosition The trading position result, positive when amm longs,
               negative when amm shorts
     */
    function queryTradeWithAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 tradeAmount,
        bool partialFill
    ) public view returns (int256 deltaCash, int256 deltaPosition) {
        require(tradeAmount != 0, "trading amount is zero");
        Context memory context = prepareContext(liquidityPool, perpetualIndex);
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        (int256 closePosition, int256 openPosition) = Utils.splitAmount(context.position, tradeAmount);
        // amm close position
        int256 closeBestPrice;
        (deltaCash, closeBestPrice) = ammClosePosition(context, perpetual, closePosition);
        context.availableCash = context.availableCash.add(deltaCash);
        context.position = context.position.add(closePosition);
        // amm open position
        (int256 openDeltaMargin, int256 openDeltaPosition, int256 openBestPrice) =
            ammOpenPosition(perpetual, context, openPosition, partialFill);
        deltaCash = deltaCash.add(openDeltaMargin);
        deltaPosition = closePosition.add(openDeltaPosition);
        int256 bestPrice = closePosition != 0 ? closeBestPrice : openBestPrice;
        // if better than best price, clip to best price
        deltaCash = deltaCash.max(bestPrice.wmul(deltaPosition).neg());
    }

    /**
     * @dev Calculate the amount of share token to mint when adding liquidity to pool
     * @param liquidityPool The liquidity pool of amm
     * @param shareTotalSupply The total supply of the share token before adding liquidity
     * @param cashToAdd The cash added to the liquidity pool
     * @return shareToMint The amount of share token to mint
     */
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
            require(shareTotalSupply == 0, "share token has no value");
            // first time
            shareToMint = newPoolMargin;
        } else {
            shareToMint = newPoolMargin.sub(poolMargin).wfrac(shareTotalSupply, poolMargin);
        }
    }

    /**
     * @dev Calculate the cash to return when removing liquidity from pool
     * @param liquidityPool The liquidity pool of amm
     * @param shareTotalSupply The total supply of the share token before removing liquidity
     * @param shareToRemove The amount of share token to remove
     * @return cashToReturn The cash to return
     */
    function getCashToReturn(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 shareToRemove
    ) public view returns (int256 cashToReturn) {
        require(shareTotalSupply > 0, "the supply of share token is zero when removing liquidity");
        Context memory context = prepareContext(liquidityPool);
        require(isAMMMarginSafe(context, 0), "amm is unsafe before removing liquidity");
        int256 poolMargin = getPoolMargin(context, 0);
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
            int256 indexPrice = perpetual.getIndexPrice();
            require(indexPrice > 0, "index price must be positive");
            // prevent amm offering negative price
            require(
                perpetual.getPosition(address(this)) <=
                    poolMargin.wdiv(perpetual.openSlippageFactor.value).wdiv(indexPrice),
                "amm is unsafe after removing liquidity"
            );
        }
        // prevent amm exceeding max leverage
        require(
            context.availableCash.add(context.positionValue).sub(cashToReturn) >=
                context.positionMargin,
            "amm exceeds max leverage after removing liquidity"
        );
    }

    /**
     * @dev Calculate the pool margin of amm
     * @param context The status of amm
     * @param slippageFactor The slippage factor of amm
     * @return poolMargin The pool margin of amm
     */
    function getPoolMargin(Context memory context, int256 slippageFactor)
        internal
        pure
        returns (int256 poolMargin)
    {
        int256 positionValue = context.indexPrice.wmul(context.position);
        int256 margin = positionValue.add(context.positionValue).add(context.availableCash);
        int256 tmp = positionValue.wmul(positionValue).mul(slippageFactor).add(context.squareValue);
        int256 beforeSqrt = margin.mul(margin).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when getting pool margin");
        poolMargin = beforeSqrt.sqrt().add(margin).div(2);
    }

    /**
     * @dev Check if amm is safe
     * @param context The status of amm
     * @param slippageFactor The slippage factor of amm
     * @return bool If amm is safe
     */
    function isAMMMarginSafe(Context memory context, int256 slippageFactor)
        internal
        pure
        returns (bool)
    {
        int256 positionValue = context.indexPrice.wmul(context.position);
        int256 minAvailableCash = positionValue.wmul(positionValue).mul(slippageFactor);
        minAvailableCash = minAvailableCash.add(context.squareValue).mul(2).sqrt().sub(
            context.positionValue.add(positionValue)
        );
        return context.availableCash >= minAvailableCash;
    }

    /**
     * @dev get the result when amm closing position
     * @param context The status of amm
     * @param perpetual The perpetual to trade
     * @param tradeAmount The trading amount
     * @return deltaCash The trading cash result, positive when amm's cash increases,
               negative when amm's cash decrease
     * @return bestPrice The best spread, calculated by spread parameter
     */
    function ammClosePosition(
        Context memory context,
        PerpetualStorage storage perpetual,
        int256 tradeAmount
    ) internal view returns (int256 deltaCash, int256 bestPrice) {
        if (tradeAmount == 0) {
            return (0, 0);
        }
        int256 positionBefore = context.position;
        require(positionBefore != 0, "position is zero when close");
        int256 slippageFactor = perpetual.closeSlippageFactor.value;
        int256 halfSpread = perpetual.halfSpread.value;
        if (tradeAmount > 0) {
            halfSpread = halfSpread.neg();
        }
        int256 maxClosePriceDiscount = perpetual.maxClosePriceDiscount.value;
        if (isAMMMarginSafe(context, slippageFactor)) {
            int256 poolMargin = getPoolMargin(context, slippageFactor);
            require(poolMargin > 0, "pool margin must be positive");
            bestPrice = _getPrice(context.indexPrice, poolMargin, positionBefore, slippageFactor)
                .wmul(halfSpread.add(Constant.SIGNED_ONE));
            deltaCash = _getDeltaMargin(
                poolMargin,
                positionBefore,
                positionBefore.add(tradeAmount),
                context.indexPrice,
                slippageFactor
            );
        } else {
            if (positionBefore > 0 && slippageFactor > Constant.SIGNED_ONE.div(2)) {
                bestPrice = context.indexPrice.wmul(Constant.SIGNED_ONE.sub(maxClosePriceDiscount));
            } else {
                bestPrice = context.indexPrice;
            }
            deltaCash = bestPrice.wmul(tradeAmount).neg();
        }
        int256 priceLimit;
        if (tradeAmount > 0) {
            priceLimit = Constant.SIGNED_ONE.add(maxClosePriceDiscount);
        } else {
            priceLimit = Constant.SIGNED_ONE.sub(maxClosePriceDiscount);
        }
        deltaCash = deltaCash.max(context.indexPrice.wmul(priceLimit).wmul(tradeAmount).neg());
        require(!Utils.hasTheSameSign(deltaCash, tradeAmount), "invalid delta cash");
    }

    function ammOpenPosition(
        PerpetualStorage storage perpetual,
        Context memory context,
        int256 tradeAmount,
        bool partialFill
    )
        private
        view
        returns (
            int256 deltaCash,
            int256 deltaPosition,
            int256 bestPrice
        )
    {
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
        int256 poolMargin = getPoolMargin(context, slippageFactor);
        require(poolMargin > 0, "pool margin must be positive");
        int256 indexPrice = context.indexPrice;
        int256 ammMaxLeverage = perpetual.ammMaxLeverage.value;
        if (positionAfter > 0) {
            int256 maxLongPosition =
                _getMaxPosition(context, poolMargin, ammMaxLeverage, slippageFactor, true);
            if (positionAfter > maxLongPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = maxLongPosition.sub(positionBefore);
                positionAfter = maxLongPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        } else {
            int256 minShortPosition =
                _getMaxPosition(context, poolMargin, ammMaxLeverage, slippageFactor, false);
            if (positionAfter < minShortPosition) {
                require(partialFill, "trade amount exceeds max amount");
                deltaPosition = minShortPosition.sub(positionBefore);
                positionAfter = minShortPosition;
            } else {
                deltaPosition = tradeAmount;
            }
        }
        deltaCash = _getDeltaMargin(
            poolMargin,
            positionBefore,
            positionAfter,
            indexPrice,
            slippageFactor
        );
        require(!Utils.hasTheSameSign(deltaCash, tradeAmount), "invalid delta cash");
        int256 halfSpread = perpetual.halfSpread.value;
        if (tradeAmount > 0) {
            halfSpread = halfSpread.neg();
        }
        bestPrice = _getPrice(indexPrice, poolMargin, positionBefore, slippageFactor).wmul(
            halfSpread.add(Constant.SIGNED_ONE)
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
                    indexPrice
                        .wmul(indexPrice)
                        .wmul(position, Round.DOWN)
                        .wmul(position, Round.DOWN)
                        .mul(perpetual.openSlippageFactor.value)
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
        return
            Constant
                .SIGNED_ONE
                .sub(indexPrice.wmul(position).wfrac(slippageFactor, poolMargin))
                .wmul(indexPrice);
    }

    function _getDeltaMargin(
        int256 poolMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 slippageFactor
    ) internal pure returns (int256 deltaCash) {
        deltaCash = positionAmount2.add(positionAmount1).wmul(indexPrice).div(2).wfrac(
            slippageFactor,
            poolMargin
        );
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
        int256 beforeSqrt =
            poolMargin.mul(poolMargin).mul(2).sub(context.squareValue).wdiv(slippageFactor);
        if (beforeSqrt <= 0) {
            return 0;
        }
        int256 maxPosition1 = beforeSqrt.sqrt().wdiv(context.indexPrice);
        int256 maxPosition2;
        beforeSqrt = poolMargin.sub(context.positionMargin).add(
            context.squareValue.div(poolMargin).div(2)
        );
        beforeSqrt = beforeSqrt.wmul(ammMaxLeverage).wmul(ammMaxLeverage).wmul(slippageFactor);
        beforeSqrt = poolMargin.sub(beforeSqrt.mul(2));
        if (beforeSqrt < 0) {
            maxPosition2 = type(int256).max;
        } else {
            maxPosition2 = beforeSqrt.mul(poolMargin).sqrt();
            maxPosition2 = poolMargin
                .sub(maxPosition2)
                .wdiv(ammMaxLeverage)
                .wdiv(slippageFactor)
                .wdiv(context.indexPrice);
        }
        maxPosition = maxPosition1.min(maxPosition2);
        if (isLongSide) {
            int256 maxPosition3 = poolMargin.wdiv(slippageFactor).wdiv(context.indexPrice);
            maxPosition = maxPosition.min(maxPosition3);
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    function getPoolMargin(Context memory context) internal pure returns (int256, bool) {
        if (isAMMMarginSafe(context, 0)) {
            return (getPoolMargin(context, 0), true);
        } else {
            return (context.availableCash.add(context.positionValue).div(2), false);
        }
    }
}
