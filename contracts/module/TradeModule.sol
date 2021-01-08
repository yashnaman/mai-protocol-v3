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
     * @notice Trade in perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of perpetual
     * @param trader The trader
     * @param amount The amount to trade
     * @param priceLimit The limit price
     * @param referrer The referrer
     * @param flags The flags of trade
     * @return int256 The delta position of trader
     */
    function trade(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer,
        uint32 flags
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        // close only
        if (flags.isCloseOnly()) {
            amount = getMaxPositionToClose(position, amount);
        }
        // query price
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount.neg(), false);
        int256 tradePrice = deltaCash.wdiv(deltaPosition).abs();
        // check price
        if (!flags.isMarketOrder()) {
            validatePrice(amount >= 0, tradePrice, priceLimit);
        }
        // trade
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg());
        (int256 lpFee, int256 totalFee) =
            updateFees(liquidityPool, perpetual, trader, referrer, deltaCash.abs());
        perpetual.updateCash(address(this), lpFee);
        perpetual.updateCash(trader, totalFee.neg());
        // account safety
        if (Utils.isOpen(position, deltaPosition.neg())) {
            require(
                perpetual.isInitialMarginSafe(trader, perpetual.getMarkPrice()),
                "trader initial margin is unsafe"
            );
        } else {
            require(
                perpetual.isMarginSafe(trader, perpetual.getMarkPrice()),
                "trader margin is unsafe"
            );
        }
        emit Trade(perpetualIndex, trader, deltaPosition.neg(), tradePrice, totalFee);
        return deltaPosition.neg();
    }

    /**
     * @notice Get fees during trading.
     * @param liquidityPool The liquidity pool
     * @param perpetual The perpetual
     * @param trader The trader
     * @param tradeValue The value of trade
     * @return lpFee The fee belongs to LP
     * @return totalFee The total fee of trade
     */
    function getFees(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address trader,
        int256 tradeValue
    )
        public
        view
        returns (
            int256,
            int256,
            int256
        )
    {
        int256 available = perpetual.getAvailableMargin(trader, perpetual.getMarkPrice());
        if (available <= 0) {
            return (0, 0, 0);
        }
        int256 lpFee = tradeValue.wmul(perpetual.lpFeeRate);
        if (available <= lpFee) {
            return (available, 0, 0);
        }
        available = available.sub(lpFee);
        int256 operatorFee = tradeValue.wmul(perpetual.operatorFeeRate);
        if (available <= operatorFee) {
            return (lpFee, available, 0);
        }
        available = available.sub(operatorFee);
        int256 vaultFee = tradeValue.wmul(liquidityPool.vaultFeeRate);
        if (available <= vaultFee) {
            return (lpFee, operatorFee, available);
        }
        return (lpFee, operatorFee, vaultFee);
    }

    /**
     * @notice Update fees during trading.
     * @param liquidityPool The liquidity pool
     * @param perpetual The perpetual
     * @param trader The trader
     * @param referrer The referrer
     * @param tradeValue The value of trade
     * @return lpFee The fee belongs to LP
     * @return totalFee The total fee of trade
     */
    function updateFees(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address trader,
        address referrer,
        int256 tradeValue
    ) public returns (int256 lpFee, int256 totalFee) {
        require(tradeValue >= 0, "negative trade value");
        int256 referrerFee;
        int256 operatorFee;
        int256 vaultFee;
        (lpFee, operatorFee, vaultFee) = getFees(liquidityPool, perpetual, trader, tradeValue);
        totalFee = lpFee.add(operatorFee).add(vaultFee);

        if (referrer != address(0) && perpetual.referralRebateRate > 0) {
            int256 lpFeeRebate = lpFee.wmul(perpetual.referralRebateRate);
            int256 operatorFeeRabate = operatorFee.wmul(perpetual.referralRebateRate);
            lpFee = lpFee.sub(lpFeeRebate);
            operatorFee = operatorFee.sub(operatorFeeRabate);
            referrerFee = lpFeeRebate.add(operatorFeeRabate);
            liquidityPool.transferToUser(payable(referrer), referrerFee);
        }

        liquidityPool.transferToUser(payable(liquidityPool.vault), vaultFee);
        liquidityPool.increaseFee(liquidityPool.operator, operatorFee);
        perpetual.decreaseTotalCollateral(totalFee);
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
        pure
        returns (int256 maxPositionToClose)
    {
        require(position != 0, "trader has no position to close");
        require(!Utils.hasTheSameSign(position, amount), "trader must be close only");
        maxPositionToClose = amount.abs() > position.abs() ? position : amount;
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
    ) internal pure {
        require(price >= 0, "negative price");
        bool isPriceSatisfied = isLong ? price <= priceLimit : price >= priceLimit;
        require(isPriceSatisfied, "price exceeds limit");
    }
}
