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
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    using PerpetualModule for Perpetual;
    using OracleModule for Perpetual;
    using CollateralModule for Perpetual;
    using SettlementModule for Perpetual;
    using CollateralModule for Core;
    using CoreModule for Core;

    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);

    // atribute
    function initialMargin(
        Perpetual storage perpetual,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader]
                .positionAmount
                .wmul(indexPrice)
                .wmul(perpetual.initialMarginRate)
                .abs()
                .max(perpetual.keeperGasReward);
    }

    function maintenanceMargin(
        Perpetual storage perpetual,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader]
                .positionAmount
                .wmul(indexPrice)
                .wmul(perpetual.maintenanceMarginRate)
                .abs()
                .max(perpetual.keeperGasReward);
    }

    function availableCashBalance(Perpetual storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        return
            perpetual.marginAccounts[trader].cashBalance.sub(
                perpetual.marginAccounts[trader].positionAmount.wmul(
                    perpetual.unitAccumulativeFunding
                )
            );
    }

    function positionAmount(Perpetual storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        return perpetual.marginAccounts[trader].positionAmount;
    }

    function margin(
        Perpetual storage perpetual,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader].positionAmount.wmul(indexPrice).add(
                availableCashBalance(perpetual, trader)
            );
    }

    function isInitialMarginSafe(Perpetual storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(perpetual, trader, perpetual.markPrice()) >=
            initialMargin(perpetual, trader, perpetual.markPrice());
    }

    function isMaintenanceMarginSafe(Perpetual storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(perpetual, trader, perpetual.markPrice()) >=
            maintenanceMargin(perpetual, trader, perpetual.markPrice());
    }

    function isMarginSafe(Perpetual storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return margin(perpetual, trader, perpetual.markPrice()) >= 0;
    }

    function isEmptyAccount(Perpetual storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            perpetual.marginAccounts[trader].cashBalance == 0 &&
            perpetual.marginAccounts[trader].positionAmount == 0;
    }

    function deposit(
        Core storage core,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        Perpetual storage perpetual = core.perpetuals[perpetualIndex];
        bool isInitial = isEmptyAccount(perpetual, trader);
        int256 totalAmount = core.transferFromUser(trader, amount);
        require(totalAmount > 0, "total amount is 0");
        perpetual.increaseDepositedCollateral(totalAmount);
        updateCashBalance(perpetual, trader, totalAmount);
        if (isInitial) {
            perpetual.registerTrader(trader);
            IFactory(core.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
        emit Deposit(perpetualIndex, trader, totalAmount);
    }

    function withdraw(
        Core storage core,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        Perpetual storage perpetual = core.perpetuals[perpetualIndex];
        core.rebalance(perpetual);
        updateCashBalance(perpetual, trader, amount.neg());
        perpetual.decreaseDepositedCollateral(amount);
        require(isInitialMarginSafe(perpetual, trader), "margin is unsafe after withdrawal");
        bool isDrained = isEmptyAccount(perpetual, trader);
        if (isDrained) {
            perpetual.deregisterTrader(trader);
            IFactory(core.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
        core.transferToUser(payable(trader), amount);
        emit Withdraw(perpetualIndex, trader, amount);
    }

    function updateCashBalance(
        Perpetual storage perpetual,
        address trader,
        int256 deltaCashBalance
    ) internal {
        perpetual.marginAccounts[trader].cashBalance = perpetual.marginAccounts[trader]
            .cashBalance
            .add(deltaCashBalance);
    }

    function updateMarginAccount(
        Perpetual storage perpetual,
        address trader,
        int256 deltaPositionAmount,
        int256 deltaCashBalance
    ) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.positionAmount = account.positionAmount.add(deltaPositionAmount);
        account.cashBalance = account.cashBalance.add(deltaCashBalance).add(
            perpetual.unitAccumulativeFunding.wmul(deltaPositionAmount)
        );
    }
}
