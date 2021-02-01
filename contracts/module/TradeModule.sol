// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../interface/IOracle.sol";

import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using OrderData for uint32;

    using AMMModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for MarginAccount;

    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 position,
        int256 price,
        int256 fee,
        int256 lpFee
    );
    event Liquidate(
        uint256 perpetualIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price,
        int256 penalty,
        int256 penaltyToLP
    );
    event TransferFeeToOperator(address indexed operator, int256 operatorFee);

    /**
     * @notice Trade the position in the perpetual between the trader (taker) and AMM (maker).
     *         The trading price is determined by AMM based on current index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position.
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The position amount of the trade
     * @param priceLimit The worst price the trader accepts
     * @param referrer The address of the referrer
     * @param flags The flags of the trade
     * @return tradeAmount The update position amount of the trader after trade
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
        require(!IOracle(perpetual.oracle).isMarketClosed(), "market is closed now");
        // close only
        if (flags.isCloseOnly()) {
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

        (int256 lpFee, int256 totalFee) =
            postTrade(liquidityPool, perpetual, trader, referrer, deltaCash, deltaPosition);
        emit Trade(
            perpetualIndex,
            trader,
            deltaPosition.neg(),
            deltaCash.wdiv(deltaPosition).abs(),
            totalFee,
            lpFee
        );
        tradeAmount = deltaPosition.neg();
    }

    /**
     * @notice Get the fees of the trade. If the margin of the trader is not enough for fee:
     *         1. If trader open position, the trade will be reverted.
     *         2. If trader close position, the fee will be decreasing in proportion according to
     *         the margin left in the trader's account
     * @param liquidityPool The liquidity pool object
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param referrer The address of the referrer
     * @param tradeValue The collateral value of the trade
     * @param hasOpened If the trader has opened position during the trade
     * @return lpFee The fee belongs to the LP
     * @return operatorFee The fee belongs to the operator
     * @return vaultFee The fee belongs to the vault
     * @return referralRebate The rebate of the refferral
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
        require(tradeValue >= 0, "trade value is negative");
        vaultFee = tradeValue.wmul(liquidityPool.getVaultFeeRate());
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
     * @dev Execute the trade. If the trader has opened position in the trade, his account should be
     *      initial margin safe after the trade. If not, his account should be margin safe
     * @param liquidityPool The liquidity pool object
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param referrer The address of the referrer
     * @param deltaCash The update cash(collateral) amount of the trader after the trade
     * @param deltaPosition The update position amount of the trader after the trade
     * @return lpFee Amount of fee for lp provider
     * @return totalFee The total fee collected from the trader after the trade
     */
    function postTrade(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address trader,
        address referrer,
        int256 deltaCash,
        int256 deltaPosition
    ) public returns (int256 lpFee, int256 totalFee) {
        // fees
        bool hasOpened = hasOpenedPosition(perpetual.getPosition(trader), deltaPosition.neg());
        int256 operatorFee;
        int256 vaultFee;
        int256 referralRebate;

        (lpFee, operatorFee, vaultFee, referralRebate) = getFees(
            liquidityPool,
            perpetual,
            trader,
            referrer,
            deltaCash.abs(),
            hasOpened
        );

        totalFee = lpFee.add(operatorFee).add(vaultFee).add(referralRebate);
        perpetual.updateCash(trader, totalFee.neg());
        perpetual.updateCash(address(this), lpFee);
        liquidityPool.transferFromPerpetualToUser(perpetual.id, referrer, referralRebate);
        liquidityPool.transferFromPerpetualToUser(perpetual.id, liquidityPool.getVault(), vaultFee);
        liquidityPool.transferFromPerpetualToUser(
            perpetual.id,
            liquidityPool.operator,
            operatorFee
        );

        emit TransferFeeToOperator(liquidityPool.operator, operatorFee);
        // safety
        int256 markPrice = perpetual.getMarkPrice();
        if (hasOpened) {
            require(perpetual.isInitialMarginSafe(trader, markPrice), "initial margin unsafe");
        } else {
            require(perpetual.isMarginSafe(trader, markPrice), "margin unsafe");
        }
    }

    /**
     * @notice Liquidate the trader if the trader is not maintenance margin safe. AMM takes the position.
     *         The liquidate price is determied by AMM. The liquidator gets the keeper gas reward.
     *         If there is penalty, AMM and the insurance fund will taker it. If there is loss,
     *         the insurance fund will cover it. If the insurance fund including the donated part is negative,
     *         the perpetual's state should enter "EMERGENCY"
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param liquidator The address of the account who initiates the liquidation
     * @param trader The address of the liquidated account
     * @return int256 The update position amount of the liquidated account
     */
    function liquidateByAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        int256 markPrice = perpetual.getMarkPrice();
        require(!perpetual.isMaintenanceMarginSafe(trader, markPrice), "trader is safe");
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, position, true);
        require(deltaPosition != 0, "insufficient liquidity");
        // 2. trade
        int256 liquidatePrice = deltaCash.wdiv(deltaPosition).abs();
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(
            trader,
            deltaPosition.neg(),
            deltaCash.add(perpetual.keeperGasReward).neg()
        );
        // 3. penalty  min(markPrice * liquidationPenaltyRate, margin / position) * deltaPosition
        int256 penalty =
            markPrice.wmul(deltaPosition).wmul(perpetual.liquidationPenaltyRate).abs().min(
                perpetual.getMargin(trader, markPrice).wfrac(deltaPosition.abs(), position.abs())
            );
        int256 penaltyToTaker;
        {
            int256 penaltyToFund;
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
        liquidityPool.transferFromPerpetualToUser(
            perpetual.id,
            liquidator,
            perpetual.keeperGasReward
        );

        emit Liquidate(
            perpetualIndex,
            address(this),
            trader,
            deltaPosition.neg(),
            liquidatePrice,
            penalty,
            penaltyToTaker
        );
        // 4. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    /**
     * @notice Liquidate the trader if the trader is not maintenance margin safe. The liquidate price is mark price.
     *         If there is penalty, The liquidator and the insurance fund will taker it. If there is loss, the
     *         insurance fund will cover it. If the insurance fund including the donated part is negative, the perpetual's
     *         state should enter "EMERGENCY". The liquidator should be initial margin safe after the liquidation if
     *         he has opened position. If not, he should be maintenance margin safe
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param liquidator The address of the account who initiates the liquidation
     * @param trader The address of the liquidated account
     * @param amount The liquidated amount of position
     * @param limitPrice The worst price which the liquidator accepts
     * @return int256 The update position amount of the liquidated account
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
        // 0. price / amount
        validatePrice(amount >= 0, markPrice, limitPrice);
        (int256 deltaCash, int256 deltaPosition) = (markPrice.wmul(amount), amount.neg());
        // 1. execute
        perpetual.updateMargin(trader, deltaPosition, deltaCash);
        perpetual.updateMargin(liquidator, deltaPosition.neg(), deltaCash.neg());
        // 2. penalty  min(markPrice * liquidationPenaltyRate, margin / position) * deltaPosition
        int256 penalty =
            markPrice.wmul(deltaPosition).wmul(perpetual.liquidationPenaltyRate).abs().min(
                perpetual.getMargin(trader, markPrice).wfrac(deltaPosition.abs(), position.abs())
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
            markPrice,
            penalty,
            0
        );
        // 5. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    /**
     * @dev Get the max position amount of trader will be closed in the trade
     * @param position The current position of trader
     * @param amount The trading amount of position
     * @return maxPositionToClose The max position amount of trader will be closed in the trade
     */
    function getMaxPositionToClose(int256 position, int256 amount)
        internal
        pure
        returns (int256 maxPositionToClose)
    {
        require(position != 0, "trader has no position to close");
        require(!Utils.hasTheSameSign(position, amount), "trader must be close only");
        maxPositionToClose = amount.abs() > position.abs() ? position.neg() : amount;
    }

    /**
     * @dev Check if the price is better than the limit price
     * @param isLong True if the side is long
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

    /*
     * @dev Check if the trader has opened position in the trade.
     *      Example: 2, 1 => true; 2, -1 => false; -2, -3 => true
     * @param amount The position of the trader after the trade
     * @param delta The update position amount of the trader after the trade
     * @return bool True if the trader has opened position in the trade
     */
    function hasOpenedPosition(int256 amount, int256 delta) internal pure returns (bool) {
        if (amount == 0) {
            return false;
        }
        return Utils.hasTheSameSign(amount, delta);
    }
}
