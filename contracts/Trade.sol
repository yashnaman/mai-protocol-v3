// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/Error.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./Type.sol";
import "./State.sol";
import "./Margin.sol";
import "./Funding.sol";
import "./Fee.sol";
import "./amm/AMMTrade.sol";

contract Trade is CallContext, Core, Oracle, Funding, Fee {

    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    int256 internal _insuranceFund1;
    int256 internal _insuranceFund2;

    function _deposit(address trader, int256 amount) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _updateCashBalance(trader, amount);
    }

    function _withdraw(address trader, int256 amount) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _updateCashBalance(trader, amount.neg());
        _isInitialMarginSafe(trader, _markPrice());
    }

    function _trade(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        _tradePosition(trader, positionAmount, priceLimit);
    }

    function _liquidate1(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        int256 deltaMargin = _tradePosition(trader, positionAmount, priceLimit);
        int256 penaltyToLiquidator = _liquidationGasReward;
        int256 penaltyToFund = deltaMargin.wmul(_liquidationPenaltyRate);
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _calculateLiquidationLoss(
            trader,
            penaltyToLiquidator,
            penaltyToFund,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(trader, penaltyFromTrader.neg());
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        liquidationLoss = newInsuraceFund2 < 0 ? newInsuraceFund2 : 0;
        // fee
        _updateTradingFee(deltaMargin);
    }

    function _liquidate2(
        address taker,
        address maker,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        int256 deltaMargin = _takePosition(taker, maker, positionAmount, priceLimit);
        int256 penaltyToLiquidator = deltaMargin
            .wmul(_liquidationPenaltyRate)
            .add(_liquidationGasReward);
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _calculateLiquidationLoss(
            maker,
            penaltyToLiquidator,
            0,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(maker, penaltyFromTrader.neg());
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        liquidationLoss = newInsuraceFund2 < 0 ? newInsuraceFund2 : 0;
        // fee
        _updateTradingFee(deltaMargin);
    }

    function _tradePosition(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 deltaMargin) {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        deltaMargin = AMMTrade.calculateDeltaMargin(
            _fundingState,
            _riskParameter,
            _marginAccounts[_self()],
            _indexPrice(),
            positionAmount
        );
        _validatePrice(positionAmount, deltaMargin.wdiv(positionAmount), priceLimit);
        int256 vaultFee = deltaMargin.wmul(_vaultFeeRate());
        int256 operatorFee = deltaMargin.wmul(_operatorFeeRate);
        int256 lpFee = deltaMargin.wmul(_liquidityProviderFeeRate);
        _updatePosition(trader, positionAmount);
        _updatePosition(_self(), positionAmount.neg());
        _updateCashBalance(trader, deltaMargin.add(lpFee).add(vaultFee).add(operatorFee).neg());
        _updateCashBalance(_self(), deltaMargin.add(lpFee));
    }

    function _takePosition(
        address taker,
        address maker,
        int256 positionAmount,
        int256 priceLimit
    ) public returns (int256 deltaMargin) {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        int256 markPrice = _markPrice();
        _validatePrice(positionAmount, markPrice, priceLimit);
        deltaMargin = markPrice.wmul(positionAmount);
        _updatePosition(taker, positionAmount);
        _updatePosition(maker, positionAmount.neg());
        _updateCashBalance(taker, deltaMargin.neg());
        _updateCashBalance(maker, deltaMargin);
    }

    function _validatePrice(int256 positionAmount, int256 price, int256 priceLimit) internal pure {
        require(price > 0, Error.INVALID_TRADING_PRICE);
        if (positionAmount > 0) {
            require(price <= priceLimit, "price too high");
        } else if (positionAmount < 0) {
            require(price >= priceLimit, "price too low");
        }
    }

    function _calculateLiquidationLoss(
        address trader,
        int256 penaltyToLiquidator,
        int256 penaltyToFund,
        int256 insuranceFund1,
        int256 insuranceFund2
    ) internal returns (
        int256 penaltyFromTrader,
        int256 nextInsuranceFund1,
        int256 nextInsuranceFund2
    ) {
        int256 penalty = penaltyToLiquidator.add(penaltyToFund);
        int256 traderMargin = _margin(trader, _markPrice());
        if (traderMargin >= penalty) {
            penaltyFromTrader = penalty;
            nextInsuranceFund1 = nextInsuranceFund1.add(penaltyToFund);
        } else {
            penaltyFromTrader = traderMargin;
            nextInsuranceFund1 = insuranceFund1.sub(penaltyToLiquidator.sub(traderMargin));
            if (nextInsuranceFund1 < 0) {
                nextInsuranceFund1 = 0;
                nextInsuranceFund2 = insuranceFund2.add(nextInsuranceFund1);
            }
        }
    }

    function _updatePosition(address trader, int256 amount) internal {
        MarginAccount memory account = _marginAccounts[trader];
        ( int256 closingAmount, int256 openingAmount ) = Utils.splitAmount(account.positionAmount, amount);
        if (closingAmount != 0) {
            _closePosition(account, closingAmount);
        }
        if (openingAmount != 0) {
            _openPosition(account, openingAmount);
        }
        _marginAccounts[trader] = account;
    }

    function _updateCashBalance(address trader, int256 amount) internal {
        _marginAccounts[trader].cashBalance = _marginAccounts[trader].cashBalance.add(amount);
    }
}