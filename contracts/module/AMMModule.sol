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
     * @dev Get the trading result when trader trades with AMM, divided into two parts:
     *      AMM closes its position and AMM opens its position
     * @param liquidityPool The liquidity pool object of AMM
     * @param perpetualIndex The index of the perpetual in the liquidity pool to trade
     * @param tradeAmount The trading amount of position, positive if AMM longs, negative if AMM shorts
     * @param partialFill Whether to allow partially trading. Set to true when liquidation trading,
     *                    set to false when normal trading
     * @return deltaCash The update cash(collateral) of AMM after the trade
     * @return deltaPosition The update position of AMM after the trade
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
        (int256 closePosition, int256 openPosition) =
            Utils.splitAmount(context.position, tradeAmount);
        // amm close position
        int256 closeBestPrice;
        (deltaCash, closeBestPrice) = ammClosePosition(context, perpetual, closePosition);
        context.availableCash = context.availableCash.add(deltaCash);
        context.position = context.position.add(closePosition);
        // amm open position
        (int256 openDeltaMargin, int256 openDeltaPosition, int256 openBestPrice) =
            ammOpenPosition(context, perpetual, openPosition, partialFill);
        deltaCash = deltaCash.add(openDeltaMargin);
        deltaPosition = closePosition.add(openDeltaPosition);
        int256 bestPrice = closePosition != 0 ? closeBestPrice : openBestPrice;
        // if better than best price, clip to best price
        deltaCash = deltaCash.max(bestPrice.wmul(deltaPosition).neg());
    }

    /**
     * @dev Calculate the amount of share token to mint when liquidity provider adds liquidity to
     *      the liquidity pool. If adding liquidity at first time for the liquidity pool, the amount
     *      of share token to mint equals to the amount of cash(collateral) to add
     * @param liquidityPool The liquidity pool object of AMM
     * @param shareTotalSupply The total supply of the share token before adding liquidity
     * @param cashToAdd The cash(collateral) added to the liquidity pool
     * @return shareToMint The amount of share token to mint
     */
    function getShareToMint(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 cashToAdd
    ) public view returns (int256 shareToMint) {
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
     * @dev Calculate the cash(collateral) to return when liquidity provider removes liquidity from
     *      the liquidity pool. Removing liquidity is forbidden at several cases:
     *      1. AMM is unsafe before removing liquidity
     *      2. AMM is unsafe after removing liquidity
     *      3. AMM will offer negative price at any perpetual after removing liquidity
     *      4. AMM will exceed maximum leverage at any perpetual after removing liquidity
     * @param liquidityPool The liquidity pool object of AMM
     * @param shareTotalSupply The total supply of the share token before removing liquidity
     * @param shareToRemove The amount of share token to redeem
     * @return cashToReturn The cash(collateral) to return
     */
    function getCashToReturn(
        LiquidityPoolStorage storage liquidityPool,
        int256 shareTotalSupply,
        int256 shareToRemove
    ) public view returns (int256 cashToReturn) {
        require(shareTotalSupply > 0, "the supply of share token is zero when removing liquidity");
        Context memory context = prepareContext(liquidityPool);
        require(isAMMSafe(context, 0), "amm is unsafe before removing liquidity");
        int256 poolMargin = calculatePoolMarginWhenSafe(context, 0);
        if (poolMargin == 0) {
            return 0;
        }
        poolMargin = shareTotalSupply.sub(shareToRemove).wfrac(poolMargin, shareTotalSupply);
        {
            int256 minPoolMargin = context.squareValue.div(2).sqrt();
            require(poolMargin >= minPoolMargin, "amm is unsafe after removing liquidity");
        }
        cashToReturn = calculateCashToReturn(context, poolMargin);
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
     * @dev Calculate the pool margin of AMM when AMM is safe. Pool margin is how much collateral of the pool
     *      considering the AMM's positions of perpetuals
     * @param context The status of AMM
     * @param slippageFactor The slippage factor of the current perpetual
     * @return poolMargin The pool margin of AMM
     */
    function calculatePoolMarginWhenSafe(Context memory context, int256 slippageFactor)
        internal
        pure
        returns (int256 poolMargin)
    {
        // The context doesn't include the current perpetual, add them.
        int256 positionValue = context.indexPrice.wmul(context.position);
        int256 margin = positionValue.add(context.positionValue).add(context.availableCash);
        int256 tmp = positionValue.wmul(positionValue).mul(slippageFactor).add(context.squareValue);
        int256 beforeSqrt = margin.mul(margin).sub(tmp.mul(2));
        require(beforeSqrt >= 0, "amm is unsafe when getting pool margin");
        poolMargin = beforeSqrt.sqrt().add(margin).div(2);
    }

    /**
     * @dev Check if AMM is safe
     * @param context The status of AMM. The context don't include the current
     *                perpetual, the status of the current perpetual should be added
     * @param slippageFactor The slippage factor of the current perpetual
     * @return bool True if AMM is safe
     */
    function isAMMSafe(Context memory context, int256 slippageFactor)
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
     * @dev Get the trading result when AMM closes its position. If AMM is unsafe, the trading price is the best price.
     *      If the trading price is too bad, it will be limited to index price * (1 +/- maximum close price discount)
     * @param context The status of AMM
     * @param perpetual The perpetual object to trade
     * @param tradeAmount The trading amount of position, positive if AMM longs, negative if AMM shorts
     * @return deltaCash The update cash(collateral) of AMM after the trade
     * @return bestPrice The best price, is used for clipping to spread price if needed outside.
     *                   If AMM is safe, best price = middle price * (1 +/- half spread).
     *                   If AMM is unsafe and normal case, best price = index price.
     *                   If AMM is unsafe and special case(position > 0 and slippage factor > 0.5),
     *                   best price = index price * (1 - maximum close price discount)
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
        int256 indexPrice = context.indexPrice;
        int256 slippageFactor = perpetual.closeSlippageFactor.value;
        int256 maxClosePriceDiscount = perpetual.maxClosePriceDiscount.value;
        int256 halfSpread =
            tradeAmount < 0 ? perpetual.halfSpread.value : perpetual.halfSpread.value.neg();
        if (isAMMSafe(context, slippageFactor)) {
            int256 poolMargin = calculatePoolMarginWhenSafe(context, slippageFactor);
            require(poolMargin > 0, "pool margin must be positive");
            bestPrice = _getMidPrice(poolMargin, indexPrice, positionBefore, slippageFactor).wmul(
                halfSpread.add(Constant.SIGNED_ONE)
            );
            deltaCash = _getDeltaCash(
                poolMargin,
                positionBefore,
                positionBefore.add(tradeAmount),
                indexPrice,
                slippageFactor
            );
        } else {
            if (positionBefore > 0 && slippageFactor > Constant.SIGNED_ONE.div(2)) {
                // special case
                bestPrice = indexPrice.wmul(Constant.SIGNED_ONE.sub(maxClosePriceDiscount));
            } else {
                bestPrice = indexPrice;
            }
            deltaCash = bestPrice.wmul(tradeAmount).neg();
        }
        int256 priceLimit =
            tradeAmount > 0
                ? Constant.SIGNED_ONE.add(maxClosePriceDiscount)
                : Constant.SIGNED_ONE.sub(maxClosePriceDiscount);
        // prevent too bad price
        deltaCash = deltaCash.max(indexPrice.wmul(priceLimit).wmul(tradeAmount).neg());
        // prevent negative price
        require(
            !Utils.hasTheSameSign(deltaCash, tradeAmount),
            "price is negative when amm closes position"
        );
    }

    /**
     * @dev Get the trading result when AMM opens its position. AMM can't open position when unsafe
     *      and can't open position to exceed the maximum position
     * @param context The status of AMM
     * @param perpetual The perpetual object to trade
     * @param tradeAmount The trading amount of position, positive if amm longs, negative if amm shorts
     * @param partialFill Whether to allow partially trading. Set to true when liquidation trading,
     *                    set to false when normal trading
     * @return deltaCash The update cash(collateral) of AMM after the trade
     * @return deltaPosition The update position of AMM after the trade
     * @return bestPrice The best price, is used for clipping to spread price if needed outside.
     *                   Equal to middle price * (1 +/- half spread)
     */
    function ammOpenPosition(
        Context memory context,
        PerpetualStorage storage perpetual,
        int256 tradeAmount,
        bool partialFill
    )
        internal
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
        int256 slippageFactor = perpetual.openSlippageFactor.value;
        if (!isAMMSafe(context, slippageFactor)) {
            require(partialFill, "amm is unsafe when open");
            return (0, 0, 0);
        }
        int256 poolMargin = calculatePoolMarginWhenSafe(context, slippageFactor);
        require(poolMargin > 0, "pool margin must be positive");
        int256 indexPrice = context.indexPrice;
        int256 positionBefore = context.position;
        int256 positionAfter = positionBefore.add(tradeAmount);
        int256 maxPosition =
            _getMaxPosition(
                context,
                poolMargin,
                perpetual.ammMaxLeverage.value,
                slippageFactor,
                positionAfter > 0
            );
        if (positionAfter.abs() > maxPosition.abs()) {
            require(partialFill, "trade amount exceeds max amount");
            // trade to max position if partialFill
            deltaPosition = maxPosition.sub(positionBefore);
            // current position already exeeds max position, can't open
            if (Utils.hasTheSameSign(deltaPosition, tradeAmount.neg())) {
                return (0, 0, 0);
            }
            positionAfter = maxPosition;
        } else {
            deltaPosition = tradeAmount;
        }
        deltaCash = _getDeltaCash(
            poolMargin,
            positionBefore,
            positionAfter,
            indexPrice,
            slippageFactor
        );
        // prevent negative price
        require(
            !Utils.hasTheSameSign(deltaCash, deltaPosition),
            "price is negative when amm opens position"
        );
        int256 halfSpread =
            tradeAmount < 0 ? perpetual.halfSpread.value : perpetual.halfSpread.value.neg();
        bestPrice = _getMidPrice(poolMargin, indexPrice, positionBefore, slippageFactor).wmul(
            halfSpread.add(Constant.SIGNED_ONE)
        );
    }

    /**
     * @dev Calculate the status of AMM
     * @param liquidityPool The liquidity pool object
     * @return Context The status of AMM
     */
    function prepareContext(LiquidityPoolStorage storage liquidityPool)
        internal
        view
        returns (Context memory)
    {
        return prepareContext(liquidityPool, liquidityPool.perpetuals.length);
    }

    /**
     * @dev Calculate the status of AMM
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool to distinguish,
     *                       set to liquidityPool.perpetuals.length to skip distinguishing.
     * @return context The status of AMM
     */
    function prepareContext(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        internal
        view
        returns (Context memory context)
    {
        for (uint256 i = 0; i < liquidityPool.perpetuals.length; i++) {
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
                // to make cashToReturn smaller, positionValue should be bigger, squareValue should be smaller
                context.positionValue = context.positionValue.add(
                    indexPrice.wmul(position, Round.UP)
                );
                context.squareValue = context.squareValue.add(
                    indexPrice
                        .wmul(indexPrice, Round.DOWN)
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
        // prevent margin balance < 0
        require(
            context.availableCash.add(context.positionValue).add(
                context.indexPrice.wmul(context.position)
            ) >= 0,
            "amm is emergency"
        );
    }

    /**
     * @dev Calculate the cash(collateral) to return when removing liquidity
     * @param context The status of AMM
     * @param poolMargin The pool margin of AMM before removing liquidity
     * @return cashToReturn The cash(collateral) to return
     */
    function calculateCashToReturn(Context memory context, int256 poolMargin)
        public
        pure
        returns (int256 cashToReturn)
    {
        if (poolMargin == 0) {
            // remove all
            return context.availableCash;
        }
        require(poolMargin > 0, "pool margin must be positive when removing liquidity");
        cashToReturn = context.squareValue.div(poolMargin).div(2).add(poolMargin).sub(
            context.positionValue
        );
        cashToReturn = context.availableCash.sub(cashToReturn);
    }

    /**
     * @dev Get the middle price offered by AMM
     * @param poolMargin The pool margin of AMM
     * @param indexPrice The index price of the perpetual
     * @param position The position of AMM in the perpetual
     * @param slippageFactor The slippage factor of AMM in the perpetual
     * @return int256 The middle price offered by AMM
     */
    function _getMidPrice(
        int256 poolMargin,
        int256 indexPrice,
        int256 position,
        int256 slippageFactor
    ) internal pure returns (int256) {
        return
            Constant
                .SIGNED_ONE
                .sub(indexPrice.wmul(position).wfrac(slippageFactor, poolMargin))
                .wmul(indexPrice);
    }

    /**
     * @dev Get update cash(collateral) of AMM if trader trades against AMM
     * @param poolMargin The pool margin of AMM
     * @param positionBefore The position of AMM in the perpetual before trading
     * @param positionAfter The position of AMM in the perpetual after trading
     * @param indexPrice The index price of the perpetual
     * @param slippageFactor The slippage factor of AMM in the perpetual
     * @return deltaCash The update cash(collateral) of AMM after trading
     */
    function _getDeltaCash(
        int256 poolMargin,
        int256 positionBefore,
        int256 positionAfter,
        int256 indexPrice,
        int256 slippageFactor
    ) internal pure returns (int256 deltaCash) {
        deltaCash = positionAfter.add(positionBefore).wmul(indexPrice).div(2).wfrac(
            slippageFactor,
            poolMargin
        );
        deltaCash = Constant.SIGNED_ONE.sub(deltaCash).wmul(indexPrice).wmul(
            positionBefore.sub(positionAfter)
        );
    }

    /**
     * @dev Get the max position of AMM in the perpetual, calculated by three restrictions:
     *      1. AMM must be safe after the trade.
     *      2. AMM mustn't exceed maximum leverage in any perpetual after the trade.
     *      3. AMM must offer positive price in any perpetual after the trade. It's easy to prove that, in the
     *         perpetual, AMM definitely offers positive price when AMM holds short position
     * @param context The status of AMM
     * @param poolMargin The pool margin of AMM
     * @param ammMaxLeverage The max leverage of AMM in the perpetual
     * @param slippageFactor The slippage factor of AMM in the perpetual
     * @return maxPosition The max position of AMM in the perpetual
     */
    function _getMaxPosition(
        Context memory context,
        int256 poolMargin,
        int256 ammMaxLeverage,
        int256 slippageFactor,
        bool isLongSide
    ) internal pure returns (int256 maxPosition) {
        int256 indexPrice = context.indexPrice;
        require(indexPrice > 0, "index price must be positive");
        int256 beforeSqrt =
            poolMargin.mul(poolMargin).mul(2).sub(context.squareValue).wdiv(slippageFactor);
        if (beforeSqrt <= 0) {
            // 1. already unsafe, can't open position
            // 2. initial amm is also this case, position = 0, available cash = 0, pool margin = 0
            return 0;
        }
        int256 maxPosition3 = beforeSqrt.sqrt().wdiv(indexPrice);
        int256 maxPosition2;
        beforeSqrt = poolMargin.sub(context.positionMargin).add(
            context.squareValue.div(poolMargin).div(2)
        );
        beforeSqrt = beforeSqrt.wmul(ammMaxLeverage).wmul(ammMaxLeverage).wmul(slippageFactor);
        beforeSqrt = poolMargin.sub(beforeSqrt.mul(2));
        if (beforeSqrt < 0) {
            // never exceed max leverage
            maxPosition2 = type(int256).max;
        } else {
            maxPosition2 = poolMargin.sub(beforeSqrt.mul(poolMargin).sqrt());
            maxPosition2 = maxPosition2.wdiv(ammMaxLeverage).wdiv(slippageFactor).wdiv(indexPrice);
        }
        maxPosition = maxPosition3.min(maxPosition2);
        if (isLongSide) {
            // long side has one more restriction than short side
            int256 maxPosition1 = poolMargin.wdiv(slippageFactor).wdiv(indexPrice);
            maxPosition = maxPosition.min(maxPosition1);
        } else {
            maxPosition = maxPosition.neg();
        }
    }

    /**
     * @dev Get pool margin of AMM, equal to 1/2 margin of AMM when AMM is unsafe. Marin of AMM:
     *      cash + index price1 * position1 + index price2 * position2 + ...
     * @param context The status of AMM
     * @return int256 The pool margin of AMM
     * @return bool True if AMM is safe
     */
    function getPoolMargin(Context memory context) internal pure returns (int256, bool) {
        if (isAMMSafe(context, 0)) {
            return (calculatePoolMarginWhenSafe(context, 0), true);
        } else {
            return (context.availableCash.add(context.positionValue).div(2), false);
        }
    }
}
