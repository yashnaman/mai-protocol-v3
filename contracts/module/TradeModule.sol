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
     * @dev     See `trade` in Perpetual.sol for details.
     *
     * @param   liquidityPool   The reference of liquidity pool storage.
     * @param   perpetualIndex  The index of the perpetual in liquidity pool.
     * @param   trader          The address of trader.
     * @param   amount          The amount of position to trader, positive for buying and negative for selling.
     * @param   limitPrice      The worst price the trader accepts.
     * @param   referrer        The address of referrer who will get rebate in the deal.
     * @param   flags           The flags of the trade.
     * @return  tradeAmount     The amount of positions actually traded in the transaction.
     */
    function trade(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public returns (int256 tradeAmount) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(!IOracle(perpetual.oracle).isMarketClosed(), "market is closed now");
        // handle close only flag
        if (flags.isCloseOnly()) {
            amount = getMaxPositionToClose(perpetual.getPosition(trader), amount);
            require(amount != 0, "no amount to close");
        }
        // query price from AMM
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount.neg(), false);
        // check price
        if (!flags.isMarketOrder()) {
            int256 tradePrice = deltaCash.wdiv(deltaPosition).abs();
            validatePrice(amount >= 0, tradePrice, limitPrice);
        }
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg());
        // handle trading fee
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
     * @dev     Get the fees of the trade. If the margin of the trader is not enough for fee:
     *            1. If trader open position, the trade will be reverted.
     *            2. If trader close position, the fee will be decreasing in proportion according to
     *               the margin left in the trader's account
     *          The rebate of referral will only calculate the lpFee and operatorFee.
     *          The vault fee will not be counted in.
     *
     * @param   liquidityPool   The reference of liquidity pool storage.
     * @param   perpetual       The reference of pereptual storage.
     * @param   trader          The address of trader.
     * @param   referrer        The address of referrer who will get rebate from the deal.
     * @param   tradeValue      The amount of trading value, measured by collateral, abs of deltaCash.
     * @param   hasOpened       True if the trader has opened position during trading.
     * @return  lpFee           The amount of fee to the Liquidity provider.
     * @return  operatorFee     The amount of fee to the operator.
     * @return  vaultFee        The amount of fee to the vault.
     * @return  referralRebate  The amount of rebate of the refferral.
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
        if (liquidityPool.getOperator() != address(0)) {
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
            int256 totalFee = lpFee.add(operatorFee).add(vaultFee);
            if (totalFee > availableMargin) {
                // maker sure the sum of fees < available margin
                int256 rate = availableMargin.wdiv(totalFee, Round.FLOOR);
                lpFee = lpFee.wmul(rate, Round.FLOOR);
                operatorFee = operatorFee.wmul(rate, Round.FLOOR);
                vaultFee = vaultFee.wmul(rate, Round.FLOOR);
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
     *          initial margin safe after the trade. If not, his account should be margin safe
     *
     * @param   liquidityPool   The reference of liquidity pool storage.
     * @param   perpetual       The reference of pereptual storage.
     * @param   trader          The address of trader.
     * @param   referrer        The address of referrer who will get rebate from the deal.
     * @param   deltaCash       The amount of cash changes in a trade.
     * @param   deltaPosition   The amount of position changes in a trade.
     * @return  lpFee           The amount of fee for lp provider
     * @return  totalFee        The total fee collected from the trader after the trade
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
        int256 operatorFee;
        int256 vaultFee;
        int256 referralRebate;
        bool hasOpened = hasOpenedPosition(perpetual.getPosition(trader), deltaPosition.neg());
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
        // safety
        require(perpetual.isMarginSafe(trader, perpetual.getMarkPrice()), "margin unsafe");
        liquidityPool.transferFromPerpetualToUser(perpetual.id, referrer, referralRebate);
        liquidityPool.transferFromPerpetualToUser(perpetual.id, liquidityPool.getVault(), vaultFee);
        address operator = liquidityPool.getOperator();
        liquidityPool.transferFromPerpetualToUser(perpetual.id, operator, operatorFee);
        emit TransferFeeToOperator(operator, operatorFee);
    }

    /**
     * @dev     See `liquidateByAMM` in Perpetual.sol for details.
     *
     * @param   liquidityPool   The reference of liquidity pool storage.
     * @param   perpetualIndex  The index of the perpetual in liquidity pool.
     * @param   liquidator          The address of the account calling the liquidation method.
     * @param   trader              The address of the liquidated account.
     * @return  liquidatedAmount    The amount of positions actually liquidated in the transaction.
     */
    function liquidateByAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader
    ) public returns (int256 liquidatedAmount) {
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
        liquidatedAmount = deltaPosition.neg();
    }

    /**
     * @dev     See `liquidateByTrader` in Perpetual.sol for details.
     *
     * @param   liquidityPool   The reference of liquidity pool storage.
     * @param   perpetualIndex  The index of the perpetual in liquidity pool.
     * @param   liquidator          The address of the account calling the liquidation method.
     * @param   trader              The address of the liquidated account.
     * @param   amount              The amount of position to be taken from liquidated trader.
     * @param   limitPrice          The worst price liquidator accepts.
     * @return  liquidatedAmount    The amount of positions actually liquidated in the transaction.
     */
    function liquidateByTrader(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice
    ) public returns (int256 liquidatedAmount) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        amount = getMaxPositionToClose(position, amount.neg());
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
        if (hasOpenedPosition(perpetual.getPosition(liquidator), deltaPosition.neg())) {
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
        liquidatedAmount = deltaPosition.neg();
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
