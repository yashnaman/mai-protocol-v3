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

contract Trade is Context, Funding, Fee {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    int256 internal _insuranceFund1;
    int256 internal _insuranceFund2;

    event ClosePosition(
        address trader,
        int256 positionAmount,
        int256 price,
        int256 fundingLoss
    );

    event OpenPosition(address trader, int256 positionAmount, int256 price);

    function _removeLiquidity(address trader, int256 amount) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        int256 penalty = AMMTrade.calculateRemovingLiquidityPenalty(
            _fundingState,
            _riskParameter,
            _marginAccounts[_self()],
            _indexPrice(),
            amount
        );
        _updateCashBalance(_self(), amount.sub(penalty).neg());
    }

    function _trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) internal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        (, , int256 openingAmount) = _tradePosition(
            trader,
            amount,
            priceLimit,
            referrer
        );
        if (openingAmount > 0) {
            _isInitialMarginSafe(trader);
        } else {
            _isMaintenanceMarginSafe(trader);
        }
    }

    function _liquidate1(
        address trader,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        (int256 deltaMargin, , ) = _tradePosition(
            trader,
            positionAmount,
            priceLimit,
            Constant.INVALID_ADDRESS
        );
        int256 penaltyToKeeper = _coreParameter.keeperGasReward;
        int256 penaltyToFund = deltaMargin.wmul(
            _coreParameter.liquidationPenaltyRate
        );
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _calculateLiquidationLoss(
            trader,
            penaltyToKeeper,
            penaltyToFund,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(trader, penaltyFromTrader.neg());
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        liquidationLoss = newInsuraceFund2 < 0 ? newInsuraceFund2 : 0;

        _increaseClaimableFee(_msgSender(), penaltyToKeeper);
        if (liquidationLoss > 0) {
            _enterEmergencyState();
        }
    }

    function _liquidate2(
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) internal returns (int256 liquidationLoss) {
        (int256 deltaMargin, , int256 takerOpeningAmount) = _takePosition(
            taker,
            maker,
            amount,
            priceLimit
        );
        if (takerOpeningAmount > 0) {
            _isInitialMarginSafe(taker);
        } else {
            _isMaintenanceMarginSafe(taker);
        }
        int256 penaltyToKeeper = deltaMargin
            .wmul(_coreParameter.liquidationPenaltyRate)
            .add(_coreParameter.keeperGasReward);
        (
            int256 penaltyFromTrader,
            int256 newInsuraceFund1,
            int256 newInsuraceFund2
        ) = _calculateLiquidationLoss(
            maker,
            penaltyToKeeper,
            0,
            _insuranceFund1,
            _insuranceFund2
        );
        _updateCashBalance(maker, penaltyFromTrader.neg());
        _insuranceFund1 = newInsuraceFund1;
        _insuranceFund2 = newInsuraceFund2;
        liquidationLoss = newInsuraceFund2 < 0 ? newInsuraceFund2 : 0;

        _increaseClaimableFee(_msgSender(), penaltyToKeeper);
        if (liquidationLoss > 0) {
            _enterEmergencyState();
        }
    }

    function _tradePosition(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        address referrer
    )
        internal
        returns (
            int256 deltaMargin,
            int256 closingAmount,
            int256 openingAmount
        )
    {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        (deltaMargin, ) = AMMTrade.trade(
            _fundingState,
            _riskParameter,
            _marginAccounts[_self()],
            _indexPrice(),
            positionAmount,
            false
        );
        _validatePrice(
            positionAmount,
            deltaMargin.wdiv(positionAmount),
            priceLimit
        );
        (
            int256 vaultFee,
            int256 operatorFee,
            int256 lpFee,
            int256 rebate
        ) = _tradingFee(deltaMargin, referrer);

        (closingAmount, openingAmount) = _updateMarginAccount(
            trader,
            positionAmount,
            deltaMargin.neg(),
            lpFee.add(vaultFee).add(operatorFee).neg()
        );
        _updateMarginAccount(_self(), positionAmount.neg(), deltaMargin, lpFee);
        // fee
        _increaseClaimableFee(_vault, vaultFee);
        _increaseClaimableFee(_operator, operatorFee);
        _increaseClaimableFee(referrer, rebate);
    }

    function _tradingFee(int256 deltaMargin, address referrer)
        internal
        view
        returns (
            int256 vaultFee,
            int256 operatorFee,
            int256 lpFee,
            int256 rebate
        )
    {
        vaultFee = deltaMargin.wmul(_coreParameter.vaultFeeRate);
        lpFee = deltaMargin.wmul(_coreParameter.lpFeeRate);
        operatorFee = deltaMargin.wmul(_coreParameter.operatorFeeRate);
        if (
            _coreParameter.referrerRebateRate > 0 &&
            referrer != Constant.INVALID_ADDRESS
        ) {
            int256 lpFeeRebate = lpFee.wmul(_coreParameter.referrerRebateRate);
            int256 operatorFeeRabate = operatorFee.wmul(
                _coreParameter.referrerRebateRate
            );
            lpFee = lpFee.sub(lpFeeRebate);
            operatorFee = operatorFee.sub(operatorFee);
            rebate = lpFeeRebate.add(operatorFeeRabate);
        }
    }

    function _takePosition(
        address taker,
        address maker,
        int256 positionAmount,
        int256 priceLimit
    )
        public
        returns (
            int256 deltaMargin,
            int256 closingAmount,
            int256 openingAmount
        )
    {
        require(positionAmount != 0, Error.INVALID_POSITION_AMOUNT);
        int256 markPrice = _markPrice();
        _validatePrice(positionAmount, markPrice, priceLimit);
        deltaMargin = markPrice.wmul(positionAmount);
        (closingAmount, openingAmount) = _updateMarginAccount(
            taker,
            positionAmount,
            deltaMargin.neg(),
            0
        );
        _updateMarginAccount(maker, positionAmount.neg(), deltaMargin, 0);
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

    function _calculateLiquidationLoss(
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
        int256 deltaPositionAmount,
        int256 deltaMargin,
        int256 fee
    ) internal returns (int256 closingAmount, int256 openingAmount) {
        MarginAccount memory account = _marginAccounts[trader];
        (closingAmount, openingAmount) = Utils.splitAmount(
            account.positionAmount,
            deltaPositionAmount
        );
        int256 price = deltaMargin.wdiv(deltaPositionAmount);
        if (closingAmount != 0) {
            _closePosition(account, closingAmount);
            int256 fundingLoss = _marginAccounts[trader].cashBalance.sub(
                account.cashBalance
            );
            emit ClosePosition(trader, deltaPositionAmount, price, fundingLoss);
        }
        if (openingAmount != 0) {
            _openPosition(account, openingAmount);
            emit OpenPosition(trader, deltaPositionAmount, price);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin).add(fee);
        _marginAccounts[trader] = account;
    }

    function _updateCashBalance(address trader, int256 amount) internal {
        _marginAccounts[trader].cashBalance = _marginAccounts[trader]
            .cashBalance
            .add(amount);
    }

    bytes32[50] private __gap;
}
