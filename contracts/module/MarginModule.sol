// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

import "../libraries/Error.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";

import "../Type.sol";
import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./SettlementModule.sol";
import "./CollateralModule.sol";

library MarginModule {
    using SafeCast for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    using OracleModule for Core;
    using CollateralModule for Core;
    using SettlementModule for Core;

    event Deposit(address trader, int256 amount);
    event Withdraw(address trader, int256 amount);

    // atribute
    function initialMargin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.initialMarginRate)
                .abs()
                .max(core.keeperGasReward);
    }

    function maintenanceMargin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.maintenanceMarginRate)
                .abs()
                .max(core.keeperGasReward);
    }

    function availableCashBalance(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        int256 fundingLoss = core.marginAccounts[trader]
            .positionAmount
            .wmul(core.unitAccumulativeFunding)
            .sub(core.marginAccounts[trader].entryFunding);
        return core.marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function positionAmount(Core storage core, address trader) internal view returns (int256) {
        return core.marginAccounts[trader].positionAmount;
    }

    function margin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader].positionAmount.wmul(core.markPrice()).add(
                availableCashBalance(core, trader)
            );
    }

    function availableMargin(Core storage core, address trader) internal view returns (int256) {
        return margin(core, trader).sub(initialMargin(core, trader));
    }

    function isInitialMarginSafe(Core storage core, address trader) internal view returns (bool) {
        return margin(core, trader) >= initialMargin(core, trader);
    }

    function isMaintenanceMarginSafe(Core storage core, address trader)
        internal
        view
        returns (bool)
    {
        return margin(core, trader) >= maintenanceMargin(core, trader);
    }

    function isMarginSafe(Core storage core, address trader) internal view returns (bool) {
        return margin(core, trader) >= 0;
    }

    function isEmptyAccount(Core storage core, address trader) internal view returns (bool) {
        return
            core.marginAccounts[trader].cashBalance == 0 &&
            core.marginAccounts[trader].positionAmount == 0 &&
            core.marginAccounts[trader].entryFunding == 0;
    }

    function deposit(
        Core storage core,
        address trader,
        int256 amount
    ) public {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        bool isNewTrader = isEmptyAccount(core, trader);
        updateCashBalance(core, trader, amount.add(msg.value.toInt256()));
        if (isNewTrader) {
            core.registerTrader(trader);
            IFactory(core.factory).activeProxy(trader);
        }
        emit Deposit(trader, amount);
    }

    function withdraw(
        Core storage core,
        address trader,
        int256 amount
    ) public {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        updateCashBalance(core, trader, amount.neg());
        require(isInitialMarginSafe(core, trader), "margin is unsafe");
        if (isEmptyAccount(core, trader)) {
            core.deregisterTrader(trader);
            IFactory(core.factory).deactiveProxy(trader);
        }
        emit Withdraw(trader, amount);
    }

    function updateCashBalance(
        Core storage core,
        address trader,
        int256 amount
    ) internal {
        core.marginAccounts[trader].cashBalance = core.marginAccounts[trader].cashBalance.add(
            amount
        );
    }

    function updateMarginAccount(
        Core storage core,
        address trader,
        int256 deltaPositionAmount,
        int256 deltaMargin
    )
        internal
        returns (
            int256 fundingLoss,
            int256 closingAmount,
            int256 openingAmount
        )
    {
        MarginAccount memory account = core.marginAccounts[trader];
        (closingAmount, openingAmount) = Utils.splitAmount(
            account.positionAmount,
            deltaPositionAmount
        );
        if (closingAmount != 0) {
            closePosition(account, closingAmount, core.unitAccumulativeFunding);
            fundingLoss = core.marginAccounts[trader].cashBalance.sub(account.cashBalance);
        }
        if (openingAmount != 0) {
            openPosition(account, openingAmount, core.unitAccumulativeFunding);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin);
        core.marginAccounts[trader] = account;
    }

    function closePosition(
        MarginAccount memory account,
        int256 amount,
        int256 unitAccumulativeFunding
    ) internal pure {
        int256 closingEntryFunding = account.entryFunding.wfrac(amount, account.positionAmount);
        int256 funding = unitAccumulativeFunding.wmul(amount).sub(closingEntryFunding);
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(account.positionAmount.abs() <= previousAmount.abs(), "must close position");
        account.cashBalance = account.cashBalance.add(funding);
        account.entryFunding = account.entryFunding.add(closingEntryFunding);
    }

    function openPosition(
        MarginAccount memory account,
        int256 amount,
        int256 unitAccumulativeFunding
    ) internal pure {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(account.positionAmount.abs() >= previousAmount.abs(), "must open position");
        account.entryFunding = account.entryFunding.add(unitAccumulativeFunding.wmul(amount));
    }
}
