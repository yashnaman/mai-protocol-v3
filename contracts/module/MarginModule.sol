// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";

import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./LiquidityPoolModule.sol";
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    using PerpetualModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using CollateralModule for PerpetualStorage;
    using SettlementModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);

    // atribute
    function initialMargin(
        PerpetualStorage storage perpetual,
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
        PerpetualStorage storage perpetual,
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

    function availableCashBalance(PerpetualStorage storage perpetual, address trader)
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

    function positionAmount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        return perpetual.marginAccounts[trader].positionAmount;
    }

    function margin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 indexPrice
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader].positionAmount.wmul(indexPrice).add(
                availableCashBalance(perpetual, trader)
            );
    }

    function isInitialMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(perpetual, trader, perpetual.markPrice()) >=
            initialMargin(perpetual, trader, perpetual.markPrice());
    }

    function isMaintenanceMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            margin(perpetual, trader, perpetual.markPrice()) >=
            maintenanceMargin(perpetual, trader, perpetual.markPrice());
    }

    function isMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return margin(perpetual, trader, perpetual.markPrice()) >= 0;
    }

    function isEmptyAccount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return
            perpetual.marginAccounts[trader].cashBalance == 0 &&
            perpetual.marginAccounts[trader].positionAmount == 0;
    }

    function deposit(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        bool isInitial = isEmptyAccount(perpetual, trader);
        int256 totalAmount = liquidityPool.transferFromUser(trader, amount);
        require(totalAmount > 0, "total amount is 0");
        perpetual.increaseDepositedCollateral(totalAmount);
        updateCashBalance(perpetual, trader, totalAmount);
        if (isInitial) {
            perpetual.registerActiveAccount(trader);
            IFactory(liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
        emit Deposit(perpetualIndex, trader, totalAmount);
    }

    function withdraw(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        liquidityPool.rebalance(perpetual);
        updateCashBalance(perpetual, trader, amount.neg());
        perpetual.decreaseDepositedCollateral(amount);
        require(isInitialMarginSafe(perpetual, trader), "margin is unsafe after withdrawal");
        bool isDrained = isEmptyAccount(perpetual, trader);
        if (isDrained) {
            perpetual.deregisterActiveAccount(trader);
            IFactory(liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
        liquidityPool.transferToUser(payable(trader), amount);
        emit Withdraw(perpetualIndex, trader, amount);
    }

    function updateCashBalance(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaCashBalance
    ) internal {
        perpetual.marginAccounts[trader].cashBalance = perpetual.marginAccounts[trader]
            .cashBalance
            .add(deltaCashBalance);
    }

    function updateMarginAccount(
        PerpetualStorage storage perpetual,
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
