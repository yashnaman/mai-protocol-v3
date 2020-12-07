// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

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
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    using OracleModule for Market;
    using CollateralModule for Market;
    using SettlementModule for Market;

    event Deposit(address trader, int256 amount);
    event Withdraw(address trader, int256 amount);

    // atribute
    function initialMargin(Market storage market, address trader) internal view returns (int256) {
        return
            market.marginAccounts[trader]
                .positionAmount
                .wmul(market.markPrice())
                .wmul(market.initialMarginRate)
                .abs()
                .max(market.keeperGasReward);
    }

    function maintenanceMargin(Market storage market, address trader)
        internal
        view
        returns (int256)
    {
        return
            market.marginAccounts[trader]
                .positionAmount
                .wmul(market.markPrice())
                .wmul(market.maintenanceMarginRate)
                .abs()
                .max(market.keeperGasReward);
    }

    function availableCashBalance(Market storage market, address trader)
        internal
        view
        returns (int256)
    {
        int256 fundingLoss = market.marginAccounts[trader]
            .positionAmount
            .wmul(market.unitAccumulativeFunding)
            .sub(market.marginAccounts[trader].entryFunding);
        return market.marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function positionAmount(Market storage market, address trader) internal view returns (int256) {
        return market.marginAccounts[trader].positionAmount;
    }

    function margin(Market storage market, address trader) internal view returns (int256) {
        return
            market.marginAccounts[trader].positionAmount.wmul(market.markPrice()).add(
                availableCashBalance(market, trader)
            );
    }

    function isInitialMarginSafe(Market storage market, address trader)
        internal
        view
        returns (bool)
    {
        return margin(market, trader) >= initialMargin(market, trader);
    }

    function isMaintenanceMarginSafe(Market storage market, address trader)
        internal
        view
        returns (bool)
    {
        return margin(market, trader) >= maintenanceMargin(market, trader);
    }

    function isMarginSafe(Market storage market, address trader) internal view returns (bool) {
        return margin(market, trader) >= 0;
    }

    function isEmptyAccount(Market storage market, address trader) internal view returns (bool) {
        return
            market.marginAccounts[trader].cashBalance == 0 &&
            market.marginAccounts[trader].positionAmount == 0;
    }

    function deposit(
        Core storage core,
        bytes32 marketID,
        address trader,
        int256 amount
    ) public {
        Market storage market = core.markets[marketID];
        bool isInitial = isEmptyAccount(market, trader);
        updateCashBalance(market, trader, amount.add(msg.value.toInt256()));
        if (isInitial) {
            market.registerTrader(trader);
            IFactory(core.factory).activeProxy(trader);
        }
        emit Deposit(trader, amount);
    }

    function withdraw(
        Core storage core,
        bytes32 marketID,
        address trader,
        int256 amount
    ) public {
        Market storage market = core.markets[marketID];
        updateCashBalance(market, trader, amount.neg());
        require(isInitialMarginSafe(market, trader), "margin is unsafe");
        bool isDrained = isEmptyAccount(market, trader);
        if (isDrained) {
            market.deregisterTrader(trader);
            IFactory(core.factory).deactiveProxy(trader);
        }
        emit Withdraw(trader, amount);
    }

    function updateCashBalance(
        Market storage market,
        address trader,
        int256 amount
    ) internal {
        market.marginAccounts[trader].cashBalance = market.marginAccounts[trader].cashBalance.add(
            amount
        );
    }

    function updateMarginAccount(
        Market storage market,
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
        MarginAccount memory account = market.marginAccounts[trader];
        (closingAmount, openingAmount) = Utils.splitAmount(
            account.positionAmount,
            deltaPositionAmount
        );
        if (closingAmount != 0) {
            closePosition(account, closingAmount, market.unitAccumulativeFunding);
            fundingLoss = market.marginAccounts[trader].cashBalance.sub(account.cashBalance);
        }
        if (openingAmount != 0) {
            openPosition(account, openingAmount, market.unitAccumulativeFunding);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin);
        market.marginAccounts[trader] = account;
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
