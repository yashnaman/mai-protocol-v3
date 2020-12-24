// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IPoolCreator.sol";

import "./OracleModule.sol";

import "./LiquidityPoolModule.sol";
import "./PerpetualModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginModule {
    using SafeMathExt for int256;
    using SafeCastUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    using PerpetualModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    function getInitialMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader]
                .position
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
                .position
                .wmul(price)
                .wmul(perpetual.maintenanceMarginRate)
                .abs()
                .max(perpetual.keeperGasReward);
    }

    function getAvailableCash(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        return account.cash.sub(account.position.wmul(perpetual.unitAccumulativeFunding));
    }

    function getPosition(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        return perpetual.marginAccounts[trader].position;
    }

    function getMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256) {
        return
            perpetual.marginAccounts[trader].position.wmul(price).add(
                getAvailableCash(perpetual, trader)
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
        return account.cash == 0 && account.position == 0;
    }

    function updateCash(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaCashBalance
    ) internal {
        perpetual.marginAccounts[trader].cash = perpetual.marginAccounts[trader].cash.add(
            deltaCashBalance
        );
    }

    function updateMarginAccount(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaPosition,
        int256 deltaCashBalance
    ) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.position = account.position.add(deltaPosition);
        account.cash = account.cash.add(deltaCashBalance).add(
            perpetual.unitAccumulativeFunding.wmul(deltaPosition)
        );
    }

    function resetMarginAccount(PerpetualStorage storage perpetual, address trader) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = 0;
        account.position = 0;
    }
}
