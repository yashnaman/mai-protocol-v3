// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/Error.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../Type.sol";
import "./AMMModule.sol";
import "./FeeModule.sol";
import "./MarginModule.sol";
import "./OracleModule.sol";

import "hardhat/console.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMModule for Core;
    using FeeModule for Core;
    using MarginModule for Market;
    using OracleModule for Market;
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
        bytes32 marketID,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public {
        Market storage market = core.markets[marketID];
        // 0. price / amount
        Receipt memory receipt;
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            marketID,
            amount.neg(),
            false
        );
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        validatePrice(receipt.tradingAmount.neg(), tradingPrice.abs(), priceLimit);
        // 1. fee
        updateTradingFees(core, market, receipt, referrer);
        // 2. execute
        updateTradingResult(core, market, receipt, trader, address(this), referrer);
        // 3. safe
        if (receipt.takerOpeningAmount != 0) {
            require(market.isInitialMarginSafe(trader), "trader initial margin is unsafe");
        } else {
            require(market.isMarginSafe(trader), "trader margin is unsafe");
        }
        // 4. event
        emitTradeEvent(receipt, trader, address(this));
    }

    function liquidateByAMM(
        Core storage core,
        bytes32 marketID,
        address trader
    ) public returns (int256) {
        Market storage market = core.markets[marketID];
        require(!market.isMaintenanceMarginSafe(trader), "trader is safe");

        Receipt memory receipt;
        int256 maxAmount = market.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            marketID,
            maxAmount,
            false
        );
        // 1. fee
        updateTradingFees(core, market, receipt, INVALID_ADDRESS);
        // 2. execute
        updateTradingResult(core, market, receipt, trader, address(this), INVALID_ADDRESS);
        // 3. penalty
        int256 penalty = receipt
            .tradingValue
            .wmul(market.liquidationPenaltyRate)
            .add(market.keeperGasReward)
            .max(market.margin(trader));
        market.updateCashBalance(trader, penalty.neg());
        updateInsuranceFund(core, penalty);
        // 4. events
        emitLiquidationEvent(receipt, trader, address(this));
        return market.keeperGasReward;
    }

    function liquidateByTrader(
        Core storage core,
        bytes32 marketID,
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public returns (int256) {
        Market storage market = core.markets[marketID];
        require(!market.isMaintenanceMarginSafe(maker), "trader is safe");

        Receipt memory receipt;
        // 0. price / amountyo
        int256 tradingPrice = market.markPrice();
        validatePrice(amount, tradingPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        updateTradingResult(core, market, receipt, taker, maker, INVALID_ADDRESS);
        // 2. penalty
        int256 penalty = receipt.tradingValue.wmul(market.liquidationPenaltyRate).max(
            market.margin(maker)
        );
        market.updateCashBalance(maker, penalty.neg());
        market.updateCashBalance(taker, penalty);
        // 3. safe
        if (receipt.takerOpeningAmount > 0) {
            require(market.isInitialMarginSafe(taker), "trader initial margin unsafe");
        } else {
            require(market.isMaintenanceMarginSafe(taker), "trader maintenance margin unsafe");
        }
        // 6. events
        emitLiquidationEvent(receipt, taker, maker);
        return 0;
    }

    function updateTradingFees(
        Core storage core,
        Market storage market,
        Receipt memory receipt,
        address referrer
    ) public view {
        int256 tradingValue = receipt.tradingValue.abs();
        receipt.vaultFee = tradingValue.wmul(core.vaultFeeRate);
        receipt.lpFee = tradingValue.wmul(market.lpFeeRate);
        receipt.operatorFee = tradingValue.wmul(market.operatorFeeRate);
        if (market.referrerRebateRate > 0 && referrer != INVALID_ADDRESS) {
            int256 lpFeeRebate = receipt.lpFee.wmul(market.referrerRebateRate);
            int256 operatorFeeRabate = receipt.operatorFee.wmul(market.referrerRebateRate);
            receipt.lpFee = receipt.lpFee.sub(lpFeeRebate);
            receipt.operatorFee = receipt.operatorFee.sub(operatorFeeRabate);
            receipt.referrerFee = lpFeeRebate.add(operatorFeeRabate);
        }
    }

    function updateTradingResult(
        Core storage core,
        Market storage market,
        Receipt memory receipt,
        address taker,
        address maker,
        address referrer
    ) internal {
        (receipt.takerFundingLoss, receipt.takerClosingAmount, receipt.takerOpeningAmount) = market
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
        (receipt.makerFundingLoss, receipt.makerClosingAmount, receipt.makerOpeningAmount) = market
            .updateMarginAccount(
            maker,
            receipt.tradingAmount,
            receipt.tradingValue.add(receipt.lpFee)
        );
        core.receiveFee(referrer, receipt.referrerFee);
        core.receiveFee(core.vault, receipt.vaultFee);
        core.receiveFee(core.operator, receipt.operatorFee);
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
