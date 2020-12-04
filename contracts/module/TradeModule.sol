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
import "./OracleModule.sol";

import "hardhat/console.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMTradeModule for Core;
    using FeeModule for Core;
    using MarginModule for Core;
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
    event Trade(address indexed trader, int256 positionAmount, int256 price, int256 fee);
    event Liquidate(
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );

    function trade(
        Core storage core,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. price / amount
        Receipt memory receipt;
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(amount.neg(), false);
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        validatePrice(receipt.tradingAmount.neg(), tradingPrice.abs(), priceLimit);
        // 1. fee
        updateTradingFees(core, receipt, referrer);
        // 2. execute
        updateTradingResult(core, receipt, trader, address(this), referrer);
        // 3. safe
        if (receipt.takerOpeningAmount != 0) {
            require(core.isInitialMarginSafe(trader), "trader initial margin is unsafe");
        } else {
            require(core.isMarginSafe(trader), "trader margin is unsafe");
        }
        // 4. event
        emitTradeEvent(receipt, trader, address(this));
    }

    function liquidateByAMM(Core storage core, address trader) public {
        Receipt memory receipt;
        int256 maxAmount = core.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(maxAmount, false);
        // 1. fee
        updateTradingFees(core, receipt, INVALID_ADDRESS);
        // 2. execute
        updateTradingResult(core, receipt, trader, address(this), INVALID_ADDRESS);
        // 3. penalty
        int256 penalty = receipt
            .tradingValue
            .wmul(core.liquidationPenaltyRate)
            .add(core.keeperGasReward)
            .max(core.margin(trader));
        core.updateCashBalance(trader, penalty.neg());
        updateInsuranceFund(core, penalty);
        // 4. events
        emitLiquidationEvent(receipt, trader, address(this));
    }

    function liquidateByTrader(
        Core storage core,
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public {
        Receipt memory receipt;
        // 0. price / amountyo
        int256 tradingPrice = core.markPrice();
        validatePrice(amount, tradingPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        updateTradingResult(core, receipt, taker, maker, INVALID_ADDRESS);
        // 2. penalty
        int256 penalty = receipt.tradingValue.wmul(core.liquidationPenaltyRate).max(
            core.margin(maker)
        );
        core.updateCashBalance(maker, penalty.neg());
        core.updateCashBalance(taker, penalty);
        // 3. safe
        if (receipt.takerOpeningAmount > 0) {
            require(core.isInitialMarginSafe(taker), "trader initial margin unsafe");
        } else {
            require(core.isMaintenanceMarginSafe(taker), "trader maintenance margin unsafe");
        }
        // 6. events
        emitLiquidationEvent(receipt, taker, maker);
    }

    function updateTradingFees(
        Core storage core,
        Receipt memory receipt,
        address referrer
    ) public view {
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

    function updateTradingResult(
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
            receipt
                .tradingValue
                .neg()
                .sub(receipt.lpFee)
                .sub(receipt.vaultFee)
                .sub(receipt.operatorFee)
                .sub(receipt.referrerFee)
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

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) internal pure {
        require(price > 0, "price is 0");
        if (amount > 0) {
            require(price <= priceLimit, "price is too high");
        } else if (amount < 0) {
            require(price >= priceLimit, "price is too low");
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
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount).abs();
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByTrade(
                taker,
                receipt.takerClosingAmount,
                tradingPrice,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByTrade(taker, receipt.takerOpeningAmount, tradingPrice);
        }
        if (receipt.makerClosingAmount != 0) {
            emit ClosePositionByTrade(
                maker,
                receipt.makerClosingAmount,
                tradingPrice,
                receipt.makerFundingLoss
            );
        }
        if (receipt.makerOpeningAmount != 0) {
            emit OpenPositionByTrade(maker, receipt.makerOpeningAmount, tradingPrice);
        }
        emit Trade(
            taker,
            receipt.tradingAmount,
            tradingPrice,
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(receipt.referrerFee)
        );
    }

    function emitLiquidationEvent(
        Receipt memory receipt,
        address taker,
        address maker
    ) internal {
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount).abs();
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByLiquidation(
                taker,
                receipt.takerClosingAmount,
                tradingPrice,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(taker, receipt.takerOpeningAmount, tradingPrice);
        }
        if (receipt.makerClosingAmount != 0) {
            emit ClosePositionByLiquidation(
                maker,
                receipt.makerClosingAmount,
                tradingPrice,
                receipt.makerFundingLoss
            );
        }
        if (receipt.makerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(maker, receipt.makerOpeningAmount, tradingPrice);
        }
        emit Liquidate(taker, maker, receipt.tradingAmount, tradingPrice.abs());
    }
}
