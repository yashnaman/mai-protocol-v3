// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using OrderData for uint32;

    using AMMModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for MarginAccount;
    using CollateralModule for LiquidityPoolStorage;

    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 position,
        int256 price,
        int256 fee
    );
    event Liquidate(
        uint256 perpetualIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price,
        int256 penalty
    );

    /**
     * @notice  Trade position between trader (taker) and AMM (maker).
     *          Trading price is determined by AMM based on current index price.
     *          Closing position
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of perpetual
     * @param trader The trader
     * @param amount The amount to trade
     * @param priceLimit The limit price
     * @param referrer The referrer
     * @param flags The flags of trade
     * @return tradeAmount int256 The delta position of trader
     */
    function trade(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer,
        uint32 flags
    ) public returns (int256 tradeAmount) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        // close only
        if (flags.isCloseOnly() || flags.isStopLossOrder() || flags.isTakeProfitOrder()) {
            amount = getMaxPositionToClose(perpetual.getPosition(trader), amount);
            require(amount != 0, "no amount to close");
        }
        // query price
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount.neg(), false);
        // check price
        if (!flags.isMarketOrder()) {
            int256 tradePrice = deltaCash.wdiv(deltaPosition).abs();
            validatePrice(amount >= 0, tradePrice, priceLimit);
        }
        // (int256 deltaCash, int256 deltaPosition) =
        //     preTrade(perpetual, trader, amount, priceLimit, flags);
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg());

        int256 totalFee =
            postTrade(liquidityPool, perpetual, trader, referrer, deltaCash, deltaPosition);
        emit Trade(
            perpetualIndex,
            trader,
            deltaPosition.neg(),
            deltaCash.wdiv(deltaPosition).abs(),
            totalFee
        );
        tradeAmount = deltaPosition.neg();
    }

    /**
     * @notice  Get fees during trading.
     *          For traders who try to close position, fee will be decreasing in proportion according to
     *          margin left in the trader's margin account;
     *
     * @param liquidityPool The liquidity pool
     * @param perpetual The perpetual
     * @param trader The trader
     * @param referrer The trader
     * @param tradeValue The value of trade
     * @param hasOpened True if trader has opened position during this trade;
     * @return lpFee            The fee belongs to LP
     * @return operatorFee      The fee belongs to operator
     * @return vaultFee         The fee belongs to vault
     * @return referralRebate   The total fee of trade
     */
    function getFees(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address trader,
        address referrer,
        int256 tradeValue,
        bool hasOpened
    )
        public
        view
        returns (
            int256 lpFee,
            int256 operatorFee,
            int256 vaultFee,
            int256 referralRebate
        )
    {
        vaultFee = tradeValue.wmul(liquidityPool.vaultFeeRate);
        lpFee = tradeValue.wmul(perpetual.lpFeeRate);
        if (liquidityPool.operator != address(0)) {
            operatorFee = tradeValue.wmul(perpetual.operatorFeeRate);
        }

        int256 totalFee = lpFee.add(operatorFee).add(vaultFee);
        int256 availableMargin = perpetual.getAvailableMargin(trader, perpetual.getMarkPrice());
        require(availableMargin >= totalFee || !hasOpened, "insufficient margin for fee");

        if (availableMargin <= 0) {
            lpFee = 0;
            operatorFee = 0;
            vaultFee = 0;
        } else {
            if (totalFee > availableMargin) {
                int256 rate = availableMargin.wdiv(totalFee);
                lpFee = lpFee.wmul(rate);
                operatorFee = operatorFee.wmul(rate);
                vaultFee = vaultFee.wmul(rate);
            }
            if (
                referrer != address(0) &&
                perpetual.referralRebateRate > 0 &&
                lpFee.add(operatorFee) > 0
            ) {
                int256 lpFeeRebate = lpFee.wmul(perpetual.referralRebateRate);
                int256 operatorFeeRabate = operatorFee.wmul(perpetual.referralRebateRate);
                referralRebate = lpFeeRebate.add(operatorFeeRabate);
                lpFee = lpFee.sub(lpFeeRebate);
                operatorFee = operatorFee.sub(operatorFeeRabate);
            }
        }
    }

    /**
     * @notice Update fees and check safety of trader's margin account after trading.
     * @param liquidityPool The liquidity pool
     * @param perpetual The perpetual
     * @param trader The trader
     * @param referrer The referrer
     * @param deltaCash Total cash amount changed during trading;
     * @param deltaPosition Total position amount changed during trading;
     * @return totalFee The total fee collected from trader during this trade transaction
     */
    function postTrade(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address trader,
        address referrer,
        int256 deltaCash,
        int256 deltaPosition
    ) internal returns (int256 totalFee) {
        // fees
        bool hasOpened = hasOpenedPosition(perpetual.getPosition(trader), deltaPosition.neg());
        (int256 lpFee, int256 operatorFee, int256 vaultFee, int256 referralRebate) =
            getFees(liquidityPool, perpetual, trader, referrer, deltaCash.abs(), hasOpened);
        totalFee = lpFee.add(operatorFee).add(vaultFee).add(referralRebate);
        perpetual.updateCash(trader, totalFee.neg());
        perpetual.updateCash(address(this), lpFee);
        liquidityPool.transferToUser(payable(referrer), referralRebate);
        liquidityPool.transferToUser(payable(liquidityPool.vault), vaultFee);
        liquidityPool.increaseFee(liquidityPool.operator, operatorFee);
        perpetual.decreaseTotalCollateral(totalFee);
        // safety
        int256 markPrice = perpetual.getMarkPrice();
        if (hasOpened) {
            require(perpetual.isInitialMarginSafe(trader, markPrice), "initial margin unsafe");
        } else {
            require(perpetual.isMarginSafe(trader, markPrice), "margin unsafe");
        }
    }

    /**
     * @notice Liquidate by amm, which means amm takes the position
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of perpetual
     * @param liquidator The account which initiating the liquidation
     * @param trader The liquidated account
     * @return int256 The delta position of liquidated account
     */
    function liquidateByAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 amount = perpetual.getPosition(trader);
        int256 markPrice = perpetual.getMarkPrice();
        require(!perpetual.isMaintenanceMarginSafe(trader, markPrice), "trader is safe");
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount, true);
        require(deltaPosition != 0, "insufficient liquidity");
        // 2. trade
        int256 liquidatePrice = deltaCash.wdiv(deltaPosition).abs();
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(
            trader,
            deltaPosition.neg(),
            deltaCash.add(perpetual.keeperGasReward).neg()
        );
        // 3. penalty
        int256 penalty =
            markPrice.wmul(deltaPosition).wmul(perpetual.liquidationPenaltyRate).abs().min(
                perpetual.getMargin(trader, markPrice)
            );
        {
            int256 penaltyToFund;
            int256 penaltyToTaker;
            if (penalty > 0) {
                penaltyToFund = penalty.wmul(perpetual.insuranceFundRate);
                penaltyToTaker = penalty.sub(penaltyToFund);
            } else {
                penaltyToFund = penalty;
                penaltyToTaker = 0;
            }
            int256 penaltyToLP = perpetual.updateInsuranceFund(penaltyToFund);
            perpetual.updateCash(address(this), penaltyToLP.add(penaltyToTaker));
            perpetual.updateCash(trader, penalty.neg());
        }
        perpetual.decreaseTotalCollateral(perpetual.keeperGasReward);
        liquidityPool.transferToUser(payable(liquidator), perpetual.keeperGasReward);
        emit Liquidate(
            perpetualIndex,
            address(this),
            trader,
            deltaPosition.neg(),
            liquidatePrice,
            penalty
        );
        // 4. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    /**
     * @notice Liquidate by trader, which means liquidator takes the position
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of perpetual
     * @param liquidator The account which initiating the liquidation
     * @param trader The liquidated account
     * @param amount The liquidated amount
     * @param limitPrice The worst price which liquidator accepts
     * @return int256 The delta position of liquidated account
     */
    function liquidateByTrader(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        amount = getMaxPositionToClose(position, amount);
        int256 markPrice = perpetual.getMarkPrice();
        require(!perpetual.isMaintenanceMarginSafe(trader, markPrice), "trader is safe");
        // 0. price / amountyo
        int256 liquidatePrice = markPrice;
        validatePrice(amount >= 0, liquidatePrice, limitPrice);
        (int256 deltaCash, int256 deltaPosition) = (liquidatePrice.wmul(amount), amount.neg());
        // 1. execute
        perpetual.updateMargin(trader, deltaPosition, deltaCash);
        perpetual.updateMargin(liquidator, deltaPosition.neg(), deltaCash.neg());
        // 2. penalty
        int256 penalty =
            markPrice.wmul(deltaPosition).wmul(perpetual.liquidationPenaltyRate).abs().min(
                perpetual.getMargin(trader, markPrice)
            );
        {
            int256 penaltyToFund;
            int256 penaltyToTaker;
            if (penalty > 0) {
                penaltyToFund = penalty.wmul(perpetual.insuranceFundRate);
                penaltyToTaker = penalty.sub(penaltyToFund);
            } else {
                penaltyToFund = penalty;
            }
            perpetual.updateCash(address(this), perpetual.updateInsuranceFund(penaltyToFund));
            perpetual.updateCash(liquidator, penaltyToTaker);
            perpetual.updateCash(trader, penalty.neg());
        }
        // 3. safe
        if (Utils.isOpen(perpetual.getPosition(liquidator), amount)) {
            require(
                perpetual.isInitialMarginSafe(liquidator, markPrice),
                "trader initial margin unsafe"
            );
        } else {
            require(
                perpetual.isMaintenanceMarginSafe(liquidator, markPrice),
                "trader maintenance margin unsafe"
            );
        }
        emit Liquidate(
            perpetualIndex,
            liquidator,
            trader,
            deltaPosition.neg(),
            liquidatePrice,
            penalty
        );
        // 5. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    /**
     * @dev Get max amount of closing position
     * @param position The current position
     * @param amount The amount of trade
     * @return maxPositionToClose The max amount of closing position
     */
    function getMaxPositionToClose(int256 position, int256 amount)
        internal
        view
        returns (int256 maxPositionToClose)
    {
        require(position != 0, "trader has no position to close");
        require(!Utils.hasTheSameSign(position, amount), "trader must be close only");
        maxPositionToClose = amount.abs() > position.abs() ? position.neg() : amount;
    }

    /**
     * @dev Check if price is better than limit price
     * @param isLong If side is long
     * @param price The price
     * @param priceLimit The limit price
     */
    function validatePrice(
        bool isLong,
        int256 price,
        int256 priceLimit
    ) internal view {
        require(price >= 0, "negative price");
        bool isPriceSatisfied = isLong ? price <= priceLimit : price >= priceLimit;
        require(isPriceSatisfied, "price exceeds limit");
    }

    /*
     * @dev Check if amount will be away from zero or cross zero if added delta.
     *      2, 1 => true; 2, -1 => false; 2, -3 => true;
     */
    function hasOpenedPosition(int256 amount, int256 delta) internal pure returns (bool) {
        return Utils.hasTheSameSign(amount, delta);
    }
}
