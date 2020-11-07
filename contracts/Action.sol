// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/Error.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./Type.sol";
import "./State.sol";

import "./module/MarginModule.sol";

contract Action is State {

    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using MarginModule for MarginAccount;

    function _deposit(
        address trader,
        int256 collateralAmount
    ) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        MarginAccount memory traderAccount = _marginAccounts[trader];
        traderAccount.increaseCashBalance(collateralAmount);
        _marginAccounts[trader] = traderAccount;
    }

    function _withdraw(
        address trader,
        int256 collateralAmount
    ) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        MarginAccount memory traderAccount = _marginAccounts[trader];
        traderAccount.decreaseCashBalance(collateralAmount);
        traderAccount.isInitialMarginSafe(_settings, _state.markPrice, _state.unitAccumulatedFundingLoss);
        _marginAccounts[trader] = traderAccount;
    }

    function _trade(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);

        MarginAccount memory account = _marginAccounts[trader];
        int256 deltaMargin = _tradePosition(account, positionAmount, priceLimit, true);
        _marginAccounts[trader] = account;
        // fee
    }

    function _liquidate(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        MarginAccount memory account = _marginAccounts[trader];
        int256 deltaMargin = _tradePosition(account, positionAmount, priceLimit, false);

        int256 penaltyToLiquidator = _settings.liquidationGasReserve;
        int256 penaltyToLP = deltaMargin.wmul(_settings.liquidationPenaltyRate1);
        int256 penaltyToFund = deltaMargin.wmul(_settings.liquidationPenaltyRate2);
        int256 newInsuraceFund = _calculateLiquidationLoss(
            account,
            penaltyToLP,
            penaltyToFund,
            _state.insuranceFund
        );
        _state.insuranceFund = newInsuraceFund > 0 ? newInsuraceFund : 0;
        liquidationLoss = newInsuraceFund < 0 ? newInsuraceFund : 0;
        // fee
    }

    function _liquidate2(
        address taker,
        address maker,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        MarginAccount memory takerAccount = _marginAccounts[taker];
        MarginAccount memory makerAccount = _marginAccounts[maker];
        int256 deltaMargin = _takePosition(takerAccount, makerAccount, positionAmount, priceLimit);
        int256 penaltyToLiquidator = _settings.liquidationPenaltyRate1.wmul(deltaMargin)
            .add(_settings.liquidationGasReserve);
        int256 penaltyToFund = _settings.liquidationPenaltyRate2.wmul(deltaMargin);
        int256 newInsuraceFund = _calculateLiquidationLoss(
            makerAccount,
            penaltyToLiquidator,
            penaltyToFund,
            _state.insuranceFund
        );
        _state.insuranceFund = newInsuraceFund > 0 ? newInsuraceFund : 0;
        liquidationLoss = newInsuraceFund < 0 ? newInsuraceFund : 0;
        // fee
    }

    function _tradePosition(
        MarginAccount memory account,
        int256 positionAmount,
        int256 priceLimit,
        bool requireSafeClose
    ) internal view returns (int256 deltaMargin) {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        (
            int256 closingAmount,
            int256 openingAmount
        ) = Utils.splitAmount(account.positionAmount, positionAmount);
        // deltaMargin = determineDeltaMargin(positionAmount);
        int256 price = deltaMargin.wdiv(positionAmount);
        _validatePrice(positionAmount, price, priceLimit);
        int256 tradingFee = _settings.liquidityProviderFeeRate
            .add(_settings.vaultFeeRate)
            .add(_settings.operatorFeeRate)
            .wmul(deltaMargin);
        account.decreaseCashBalance(deltaMargin.add(tradingFee));
        account.updatePosition(closingAmount, openingAmount, _state.unitAccumulatedFundingLoss);
        if (openingAmount > 0) {
            _requireSafeOpen(account);
        } else if (requireSafeClose) {
            _requireSafeClose(account);
        }
    }

    function _takePosition(
        MarginAccount memory takerAccount,
        MarginAccount memory makerAccount,
        int256 positionAmount,
        int256 priceLimit
    ) public view returns (int256 deltaMargin) {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        int256 price = _state.markPrice;
        _validatePrice(positionAmount, price, priceLimit);
        (
            int256 takerClosingAmount,
            int256 takerOpeningAmount
        ) = Utils.splitAmount(takerAccount.positionAmount, positionAmount);
        (
            int256 makerClosingAmount,
            int256 makerOpeningAmount
        ) = Utils.splitAmount(makerAccount.positionAmount, positionAmount.neg());

        deltaMargin = price.wmul(positionAmount);
        takerAccount.decreaseCashBalance(deltaMargin);
        makerAccount.increaseCashBalance(deltaMargin);
        takerAccount.updatePosition(takerClosingAmount, takerOpeningAmount, _state.unitAccumulatedFundingLoss);
        makerAccount.updatePosition(makerClosingAmount, makerOpeningAmount, _state.unitAccumulatedFundingLoss);
        takerOpeningAmount > 0 ? _requireSafeOpen(takerAccount) : _requireSafeClose(takerAccount);
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
        MarginAccount memory account,
        int256 penaltyToLiquidator,
        int256 penaltyToFund,
        int256 insuranceFund
    ) internal view returns (int256 nextInsuranceFund) {
        int256 penalty = penaltyToLiquidator.add(penaltyToFund);
        if (account.cashBalance >= penalty) {
            account.decreaseCashBalance(penalty);
            nextInsuranceFund = insuranceFund.add(penaltyToFund);
        } else {
            int256 accountMargin = account.margin(_state.markPrice, _state.unitAccumulatedFundingLoss);
            if (accountMargin.add(insuranceFund) >= penaltyToLiquidator) {
                account.decreaseCashBalance(accountMargin);
                nextInsuranceFund = accountMargin
                    .sub(penaltyToLiquidator)
                    .add(insuranceFund);
            } else {
                account.decreaseCashBalance(accountMargin);
                insuranceFund = penaltyToLiquidator
                    .sub(insuranceFund)
                    .sub(accountMargin);
            }
        }
    }

    function _requireSafeOpen(MarginAccount memory account) internal view {
        require(
            account.isInitialMarginSafe(_settings, _state.markPrice, _state.unitAccumulatedFundingLoss),
            Error.ACCOUNT_IM_UNSAFE
        );
    }

    function _requireSafeClose(MarginAccount memory account) internal view {
        require(
            account.isMaintenanceMarginSafe(_settings, _state.markPrice, _state.unitAccumulatedFundingLoss),
            Error.ACCOUNT_MM_UNSAFE
        );
    }
}