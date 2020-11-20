// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/Error.sol";
import "./libraries/Constant.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./Type.sol";
import "./State.sol";
import "./Margin.sol";
import "./Funding.sol";
import "./Fee.sol";
import "./amm/AMMTrade.sol";

import "./interface/IShareToken.sol";

contract Trade is Context, Funding, Fee {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    struct Receipt {
        int256 tradingValue;
        int256 tradingAmount;
        int256 lpFee;
        int256 vaultFee;
        int256 operatorFee;
        int256 referrerFee;
        int256 takerOpeningAmount;
        int256 makerOpeningAmount;
        int256 takerClosingAmount;
        int256 makerClosingAmount;
        int256 takerFundingLoss;
        int256 makerFundingLoss;
    }

    int256 internal _insuranceFund1;
    int256 internal _insuranceFund2;

    event ClosePositionByTrade(
        address trader,
        int256 amount,
        int256 price,
        int256 fundingLoss
    );
    event OpenPositionByTrade(address trader, int256 amount, int256 price);

    event ClosePositionByLiquidation(
        address trader,
        int256 amount,
        int256 price,
        int256 fundingLoss
    );
    event OpenPositionByLiquidation(
        address trader,
        int256 amount,
        int256 price
    );

    function _trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) internal returns (Receipt memory receipt) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        receipt = _tradePosition(trader, amount, priceLimit, referrer, false);
        if (receipt.takerOpeningAmount != 0) {
            _isInitialMarginSafe(trader);
        } else {
            _isMaintenanceMarginSafe(trader);
        }
        int256 price = receipt.tradingValue.wdiv(receipt.tradingAmount);
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByTrade(
                trader,
                receipt.tradingAmount,
                price,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByTrade(trader, receipt.tradingAmount, price);
        }
    }

    function _liquidate1(
        address trader,
        int256 amount,
        int256 priceLimit
    ) internal returns (Receipt memory receipt) {
        receipt = _tradePosition(
            trader,
            amount,
            priceLimit,
            Constant.INVALID_ADDRESS,
            true
        );
        int256 penaltyToKeeper = _coreParameter.keeperGasReward;
        int256 penaltyToFund = receipt.tradingValue.wmul(
            _coreParameter.liquidationPenaltyRate
        );
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _liquidationLoss(
            trader,
            penaltyToKeeper,
            penaltyToFund,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(trader, penaltyFromTrader.neg());
        _increaseClaimableFee(_msgSender(), penaltyToKeeper);
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        if (newInsuraceFund2 < 0) {
            _enterEmergencyState();
        }
        int256 price = receipt.tradingValue.wdiv(receipt.tradingAmount);
        if (receipt.takerClosingAmount != 0) {
            emit ClosePositionByLiquidation(
                trader,
                receipt.tradingAmount,
                price,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(
                trader,
                receipt.tradingAmount,
                price
            );
        }
    }

    function _liquidate2(
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) internal returns (Receipt memory receipt) {
        receipt = _takePosition(taker, maker, amount, priceLimit);
        if (receipt.takerOpeningAmount > 0) {
            _isInitialMarginSafe(taker);
        } else {
            _isMaintenanceMarginSafe(taker);
        }
        int256 penaltyToKeeper = receipt
            .tradingValue
            .wmul(_coreParameter.liquidationPenaltyRate)
            .add(_coreParameter.keeperGasReward);
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _liquidationLoss(
            maker,
            penaltyToKeeper,
            0,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(maker, penaltyFromTrader.neg());
        _increaseClaimableFee(_msgSender(), penaltyToKeeper);
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        if (newInsuraceFund2 < 0) {
            _enterEmergencyState();
        }
        int256 price = receipt.tradingValue.wdiv(receipt.tradingAmount);
        if (receipt.takerOpeningAmount != 0) {
            emit ClosePositionByLiquidation(
                taker,
                receipt.tradingAmount,
                price,
                receipt.takerFundingLoss
            );
        }
        if (receipt.takerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(taker, receipt.tradingAmount, price);
        }
        if (receipt.makerOpeningAmount != 0) {
            emit ClosePositionByLiquidation(
                maker,
                receipt.tradingAmount,
                price,
                receipt.makerFundingLoss
            );
        }
        if (receipt.makerOpeningAmount != 0) {
            emit OpenPositionByLiquidation(maker, receipt.tradingAmount, price);
        }
    }

    function _tradePosition(
        address trader,
        int256 priceLimit,
        int256 amount,
        address referrer,
        bool allowPartialFill
    ) internal returns (Receipt memory receipt) {
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        // 0. delta margin (value)
        (receipt.tradingValue, receipt.tradingAmount) = AMMTrade.trade(
            _fundingState,
            _riskParameter,
            _marginAccounts[_self()],
            _indexPrice(),
            amount,
            allowPartialFill
        );
        _validatePrice(receipt.tradingValue.wdiv(amount), amount, priceLimit);
        // 1. fee
        _setTradingFee(receipt, referrer);
        // 2. execute
        (
            receipt.takerFundingLoss,
            receipt.takerClosingAmount,
            receipt.takerOpeningAmount
        ) = _updateMarginAccount(
            trader,
            amount,
            receipt
                .tradingValue
                .add(receipt.lpFee)
                .add(receipt.vaultFee)
                .add(receipt.operatorFee)
                .neg()
        );
        (
            receipt.makerFundingLoss,
            receipt.makerClosingAmount,
            receipt.makerOpeningAmount
        ) = _updateMarginAccount(
            _self(),
            amount,
            receipt.tradingValue.add(receipt.lpFee)
        );
        // 3. trading fee
        _increaseClaimableFee(referrer, receipt.referrerFee);
        _increaseClaimableFee(_operator, receipt.operatorFee);
        _increaseClaimableFee(_vault, receipt.vaultFee);
    }

    function _takePosition(
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public returns (Receipt memory receipt) {
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        // 1. price
        int256 markPrice = _markPrice();
        _validatePrice(amount, markPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (
            markPrice.wmul(amount),
            amount
        );
        // 2. update margin account
        (
            receipt.takerFundingLoss,
            receipt.takerClosingAmount,
            receipt.takerOpeningAmount
        ) = _updateMarginAccount(taker, amount, receipt.tradingValue.neg());
        (
            receipt.makerFundingLoss,
            receipt.makerClosingAmount,
            receipt.makerOpeningAmount
        ) = _updateMarginAccount(maker, amount, receipt.tradingValue);
        // 3. no trading fee
    }

    function _setTradingFee(Receipt memory receipt, address referrer)
        internal
        view
    {
        int256 tradingValue = receipt.tradingValue;
        receipt.lpFee = tradingValue.wmul(_coreParameter.lpFeeRate);
        receipt.vaultFee = tradingValue.wmul(_coreParameter.vaultFeeRate);
        receipt.operatorFee = tradingValue.wmul(_coreParameter.operatorFeeRate);
        if (
            _coreParameter.referrerRebateRate > 0 &&
            referrer != Constant.INVALID_ADDRESS
        ) {
            int256 lpFeeRebate = receipt.lpFee.wmul(
                _coreParameter.referrerRebateRate
            );
            int256 operatorFeeRabate = receipt.operatorFee.wmul(
                _coreParameter.referrerRebateRate
            );
            receipt.lpFee = receipt.lpFee.sub(lpFeeRebate);
            receipt.operatorFee = receipt.operatorFee.sub(operatorFeeRabate);
            receipt.referrerFee = lpFeeRebate.add(operatorFeeRabate);
        }
    }

    function _validatePrice(
        int256 positionAmount,
        int256 price,
        int256 priceLimit
    ) internal pure {
        require(price > 0, Error.INVALID_TRADING_PRICE);
        if (positionAmount > 0) {
            require(price <= priceLimit, "price too high");
        } else if (positionAmount < 0) {
            require(price >= priceLimit, "price too low");
        }
    }

    function _liquidationLoss(
        address trader,
        int256 penaltyToLiquidator,
        int256 penaltyToFund,
        int256 insuranceFund1,
        int256 insuranceFund2
    )
        internal
        returns (
            int256 penaltyFromTrader,
            int256 nextInsuranceFund1,
            int256 nextInsuranceFund2
        )
    {
        int256 penalty = penaltyToLiquidator.add(penaltyToFund);
        int256 traderMargin = _margin(trader);
        if (traderMargin >= penalty) {
            penaltyFromTrader = penalty;
            nextInsuranceFund1 = nextInsuranceFund1.add(penaltyToFund);
        } else {
            penaltyFromTrader = traderMargin;
            nextInsuranceFund1 = insuranceFund1.sub(
                penaltyToLiquidator.sub(traderMargin)
            );
            if (nextInsuranceFund1 < 0) {
                nextInsuranceFund1 = 0;
                nextInsuranceFund2 = insuranceFund2.add(nextInsuranceFund1);
            }
        }
    }

    function _updateMarginAccount(
        address trader,
        int256 amount,
        int256 tradingValue
    )
        internal
        returns (
            int256 fundingLoss,
            int256 closingAmount,
            int256 openingAmount
        )
    {
        MarginAccount memory account = _marginAccounts[trader];
        (closingAmount, openingAmount) = Utils.splitAmount(
            account.positionAmount,
            amount
        );
        if (closingAmount != 0) {
            _closePosition(account, closingAmount);
            fundingLoss = _marginAccounts[trader].cashBalance.sub(
                account.cashBalance
            );
        }
        if (openingAmount != 0) {
            _openPosition(account, openingAmount);
        }
        account.cashBalance = account.cashBalance.add(tradingValue);
        _marginAccounts[trader] = account;
    }

    function _updateCashBalance(address trader, int256 amount) internal {
        _marginAccounts[trader].cashBalance = _marginAccounts[trader]
            .cashBalance
            .add(amount);
    }

    bytes32[50] private __gap;
}
