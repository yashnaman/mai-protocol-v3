// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/Error.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../Type.sol";
import "./AMMTradeModule.sol";
import "./FeeModule.sol";
import "./MarginModule.sol";
import "./StateModule.sol";
import "./OracleModule.sol";

import "hardhat/console.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMTradeModule for Core;
    using FeeModule for Core;
    using MarginModule for Core;
    using StateModule for Core;
    using OracleModule for Core;
    using MarginModule for MarginAccount;

    address internal constant INVALID_ADDRESS = address(0);

    event ClosePositionByTrade(address trader, int256 amount, int256 price, int256 fundingLoss);
    event OpenPositionByTrade(address trader, int256 amount, int256 price);

    event ClosePositionByLiquidation(
        address trader,
        int256 amount,
        int256 price,
        int256 fundingLoss
    );
    event OpenPositionByLiquidation(address trader, int256 amount, int256 price);

    function trade(
        Core storage core,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public returns (Receipt memory receipt) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(amount.neg(), false);
        console.log(
            "DEBUG-1: %s %s",
            uint256(receipt.tradingValue),
            uint256(receipt.tradingAmount)
        );
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        console.log("DEBUG-2: %s", uint256(tradingPrice));
        validatePrice(receipt.tradingAmount.neg(), tradingPrice.abs(), priceLimit);
        // 1. fee
        setTradingFee(core, receipt, referrer);
        console.log(
            "DEBUG-3: %s %s %s",
            uint256(receipt.lpFee),
            uint256(receipt.vaultFee),
            uint256(receipt.operatorFee)
        );
        // 2. execute
        executeTrading(core, receipt, trader, address(this), referrer);
        // 3. safe
        if (receipt.takerOpeningAmount != 0) {
            core.isInitialMarginSafe(trader);
        } else {
            core.isMaintenanceMarginSafe(trader);
        }
        // 4. event
        emitTradeEvent(receipt, trader, address(this));
    }

    function liquidateByAMM(Core storage core, address trader)
        public
        returns (Receipt memory receipt)
    {
        int256 maxAmount = core.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(maxAmount, false);
        // 1. fee
        setTradingFee(core, receipt, INVALID_ADDRESS);
        // 2. execute
        executeTrading(core, receipt, trader, address(this), INVALID_ADDRESS);
        // 3. penalty
        (int256 traderPenalty, int256 liquidatorReward) = calculatePenalty(
            core,
            trader,
            receipt.tradingValue,
            core.keeperGasReward
        );
        core.updateCashBalance(trader, traderPenalty.neg());
        updateInsuranceFund(core, liquidatorReward);
        // 4. settle?
        if (core.donatedInsuranceFund < 0) {
            core.enterEmergencyState();
        }
        // 4. events
        emitTradeEvent(receipt, trader, address(this));
    }

    function liquidateByTrader(
        Core storage core,
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public returns (Receipt memory receipt) {
        // 0. price / amount
        int256 tradingPrice = core.markPrice();
        validatePrice(amount, tradingPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        executeTrading(core, receipt, taker, maker, INVALID_ADDRESS);
        // 2. penalty
        (int256 traderPenalty, ) = calculatePenalty(core, maker, receipt.tradingValue, 0);
        core.updateCashBalance(taker, traderPenalty);
        core.updateCashBalance(maker, traderPenalty.neg());
        // 3. safe
        if (receipt.takerOpeningAmount > 0) {
            core.isInitialMarginSafe(taker);
        } else {
            core.isMaintenanceMarginSafe(taker);
        }
        // 4. settle?
        if (core.donatedInsuranceFund < 0) {
            core.enterEmergencyState();
        }
        // 6. events
        emitLiquidationEvent(receipt, taker, maker);
    }

    function executeTrading(
        Core storage core,
        Receipt memory receipt,
        address taker,
        address maker,
        address referrer
    ) internal {
        (receipt.takerFundingLoss, receipt.takerClosingAmount, receipt.takerOpeningAmount) = core
            .updateMarginAccount(
            taker,
            receipt.tradingAmount.neg(),
            receipt.tradingValue.neg().sub(receipt.lpFee).sub(receipt.vaultFee).sub(
                receipt.operatorFee
            )
        );
        (receipt.makerFundingLoss, receipt.makerClosingAmount, receipt.makerOpeningAmount) = core
            .updateMarginAccount(
            maker,
            receipt.tradingAmount,
            receipt.tradingValue.add(receipt.lpFee)
        );
        core.increaseClaimableFee(referrer, receipt.referrerFee);
        core.increaseClaimableFee(core.operator, receipt.operatorFee);
        core.increaseClaimableFee(core.vault, receipt.vaultFee);
    }

    function setTradingFee(
        Core storage core,
        Receipt memory receipt,
        address referrer
    ) internal view {
        int256 tradingValue = receipt.tradingValue.abs();
        receipt.lpFee = tradingValue.wmul(core.lpFeeRate);
        receipt.vaultFee = tradingValue.wmul(core.vaultFeeRate);
        receipt.operatorFee = tradingValue.wmul(core.operatorFeeRate);
        if (core.referrerRebateRate > 0 && referrer != INVALID_ADDRESS) {
            int256 lpFeeRebate = receipt.lpFee.wmul(core.referrerRebateRate);
            int256 operatorFeeRabate = receipt.operatorFee.wmul(core.referrerRebateRate);
            receipt.lpFee = receipt.lpFee.sub(lpFeeRebate);
            receipt.operatorFee = receipt.operatorFee.sub(operatorFeeRabate);
            receipt.referrerFee = lpFeeRebate.add(operatorFeeRabate);
        }
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) internal pure {
        require(price > 0, Error.INVALID_TRADING_PRICE);
        if (amount > 0) {
            require(price <= priceLimit, "price too high");
        } else if (amount < 0) {
            require(price >= priceLimit, "price too low");
        }
    }

    function calculatePenalty(
        Core storage core,
        address trader,
        int256 liquidationValue,
        int256 keeperReward
    ) internal view returns (int256 traderPenalty, int256 liquidatorReward) {
        int256 penalty = liquidationValue.wmul(core.liquidationPenaltyRate);
        traderPenalty = penalty.add(keeperReward);
        liquidatorReward = penalty;
        int256 traderMargin = core.margin(trader);
        if (traderMargin < traderPenalty) {
            traderPenalty = traderMargin;
            liquidatorReward = traderMargin.sub(traderPenalty);
        }
    }

    function updateInsuranceFund(Core storage core, int256 fund) internal {
        core.insuranceFund = core.insuranceFund.add(fund);
        // but fundGain could be negative in worst case
        if (core.insuranceFund < 0) {
            // then donatedInsuranceFund will cover such loss
            core.donatedInsuranceFund = core.donatedInsuranceFund.add(core.insuranceFund);
            core.insuranceFund = 0;
        }
    }

    function emitTradeEvent(
        Receipt memory receipt,
        address taker,
        address maker
    ) internal {
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByTrade(
                taker,
                receipt.tradingAmount,
                tradingPrice,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByTrade(taker, receipt.tradingAmount, tradingPrice);
        }
        if (receipt.makerClosingAmount != 0) {
            emit ClosePositionByTrade(
                maker,
                receipt.tradingAmount,
                tradingPrice,
                receipt.makerFundingLoss
            );
        }
        if (receipt.makerOpeningAmount != 0) {
            emit OpenPositionByTrade(maker, receipt.tradingAmount, tradingPrice);
        }
    }

    function emitLiquidationEvent(
        Receipt memory receipt,
        address taker,
        address maker
    ) internal {
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByLiquidation(
                taker,
                receipt.tradingAmount,
                tradingPrice,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(taker, receipt.tradingAmount, tradingPrice);
        }
        if (receipt.makerClosingAmount != 0) {
            emit ClosePositionByLiquidation(
                maker,
                receipt.tradingAmount,
                tradingPrice,
                receipt.makerFundingLoss
            );
        }
        if (receipt.makerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(maker, receipt.tradingAmount, tradingPrice);
        }
    }
}
