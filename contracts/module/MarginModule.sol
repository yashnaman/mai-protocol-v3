// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";

import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./CoreModule.sol";
import "./MarketModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    using MarketModule for Market;
    using OracleModule for Market;
    using CollateralModule for Market;
    using SettlementModule for Market;
    using CollateralModule for Core;
    using CoreModule for Core;

    event Deposit(uint256 marketIndex, address trader, int256 amount);
    event Withdraw(uint256 marketIndex, address trader, int256 amount);

    // atribute
    function initialMargin(
        Market storage market,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            market.marginAccounts[trader]
                .positionAmount
                .wmul(indexPrice)
                .wmul(market.initialMarginRate)
                .abs()
                .max(market.keeperGasReward);
    }

    function maintenanceMargin(
        Market storage market,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            market.marginAccounts[trader]
                .positionAmount
                .wmul(indexPrice)
                .wmul(market.maintenanceMarginRate)
                .abs()
                .max(market.keeperGasReward);
    }

    function availableCashBalance(Market storage market, address trader)
        internal
        view
        returns (int256)
    {
        return
            market.marginAccounts[trader].cashBalance.sub(
                market.marginAccounts[trader].positionAmount.wmul(market.unitAccumulativeFunding)
            );
    }

    function positionAmount(Market storage market, address trader) internal view returns (int256) {
        return market.marginAccounts[trader].positionAmount;
    }

    function margin(
        Market storage market,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            market.marginAccounts[trader].positionAmount.wmul(indexPrice).add(
                availableCashBalance(market, trader)
            );
    }

    function isInitialMarginSafe(Market storage market, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(market, trader, market.markPrice()) >=
            initialMargin(market, trader, market.markPrice());
    }

    function isMaintenanceMarginSafe(Market storage market, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(market, trader, market.markPrice()) >=
            maintenanceMargin(market, trader, market.markPrice());
    }

    function isMarginSafe(Market storage market, address trader) internal view returns (bool) {
        return margin(market, trader, market.markPrice()) >= 0;
    }

    function isEmptyAccount(Market storage market, address trader) internal view returns (bool) {
        return
            market.marginAccounts[trader].cashBalance == 0 &&
            market.marginAccounts[trader].positionAmount == 0;
    }

    function deposit(
        Core storage core,
        uint256 marketIndex,
        address trader,
        int256 amount
    ) public {
        Market storage market = core.markets[marketIndex];
        bool isInitial = isEmptyAccount(market, trader);
        int256 totalAmount = core.transferFromUser(trader, amount);
        require(totalAmount > 0, "total amount is 0");
        market.increaseDepositedCollateral(totalAmount);
        updateCashBalance(market, trader, totalAmount);
        if (isInitial) {
            market.registerTrader(trader);
            IFactory(core.factory).activateLiquidityPoolFor(trader, marketIndex);
        }
        emit Deposit(marketIndex, trader, totalAmount);
    }

    function withdraw(
        Core storage core,
        uint256 marketIndex,
        address trader,
        int256 amount
    ) public {
        Market storage market = core.markets[marketIndex];
        core.rebalance(market);
        updateCashBalance(market, trader, amount.neg());
        market.decreaseDepositedCollateral(amount);
        require(isInitialMarginSafe(market, trader), "margin is unsafe after withdrawal");
        bool isDrained = isEmptyAccount(market, trader);
        if (isDrained) {
            market.deregisterTrader(trader);
            IFactory(core.factory).deactivateLiquidityPoolFor(trader, marketIndex);
        }
        core.transferToUser(payable(trader), amount);
        emit Withdraw(marketIndex, trader, amount);
    }

    function updateCashBalance(
        Market storage market,
        address trader,
        int256 deltaCashBalance
    ) internal {
        market.marginAccounts[trader].cashBalance = market.marginAccounts[trader].cashBalance.add(
            deltaCashBalance
        );
    }

    function updateMarginAccount(
        Market storage market,
        address trader,
        int256 deltaPositionAmount,
        int256 deltaCashBalance
    ) internal {
        MarginAccount storage account = market.marginAccounts[trader];
        account.positionAmount = account.positionAmount.add(deltaPositionAmount);
        account.cashBalance = account.cashBalance.add(deltaCashBalance).add(
            market.unitAccumulativeFunding.wmul(deltaPositionAmount)
        );
    }
}
