// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IPoolCreator.sol";

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

    function getInitialMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader]
                .positionAmount
                .wmul(price)
                .wmul(perpetual.initialMarginRate)
                .abs();
    }

    function getMaintenanceMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader]
                .positionAmount
                .wmul(price)
                .wmul(perpetual.maintenanceMarginRate)
                .abs()
                .max(perpetual.keeperGasReward);
    }

    function getAvailableCashBalance(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        return
            account.cashBalance.sub(account.positionAmount.wmul(perpetual.unitAccumulativeFunding));
    }

    function getPositionAmount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        return perpetual.marginAccounts[trader].positionAmount;
    }

    function getMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader].positionAmount.wmul(price).add(
                getAvailableCashBalance(perpetual, trader)
            );
    }

    function isInitialMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        int256 price = perpetual.getMarkPrice();
        int256 threshold = getInitialMargin(perpetual, trader, price).max(
            perpetual.keeperGasReward
        );
        return getMargin(perpetual, trader, price) >= threshold;
    }

    function isMaintenanceMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        int256 price = perpetual.getMarkPrice();
        int256 threshold = getMaintenanceMargin(perpetual, trader, price).max(
            perpetual.keeperGasReward
        );
        return getMargin(perpetual, trader, price) >= threshold;
    }

    function isMarginSafe(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        return getMargin(perpetual, trader, perpetual.getMarkPrice()) >= 0;
    }

    function isEmptyAccount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        return account.cashBalance == 0 && account.positionAmount == 0;
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
        perpetual.increaseCollateralAmount(totalAmount);
        updateCashBalance(perpetual, trader, totalAmount);
        if (isInitial) {
            perpetual.registerActiveAccount(trader);
            IPoolCreator(liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
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
        perpetual.decreaseCollateralAmount(amount);
        require(isInitialMarginSafe(perpetual, trader), "margin is unsafe after withdrawal");
        if (isEmptyAccount(perpetual, trader)) {
            perpetual.deregisterActiveAccount(trader);
            IPoolCreator(liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
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

    function resetMarginAccount(PerpetualStorage storage perpetual, address trader) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cashBalance = 0;
        account.positionAmount = 0;
    }
}
