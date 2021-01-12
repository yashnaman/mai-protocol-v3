// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginAccountModule {
    using SafeMathExt for int256;
    using SafeCastUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    /**
     * @dev Initial margin = price * abs(position) * initial margin rate
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the initial margin
     * @return initialMargin The initial margin of the trader
     */
    function getInitialMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 initialMargin) {
        initialMargin = perpetual.marginAccounts[trader]
            .position
            .wmul(price)
            .wmul(perpetual.initialMarginRate)
            .abs();
    }

    /**
     * @dev Maintenance margin = price * abs(position) * maintenance margin rate
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the  maintenance margin
     * @return maintenanceMargin The maintenance margin of the trader
     */
    function getMaintenanceMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 maintenanceMargin) {
        maintenanceMargin = perpetual.marginAccounts[trader]
            .position
            .wmul(price)
            .wmul(perpetual.maintenanceMarginRate)
            .abs();
    }

    /**
     * @dev Available cash = cash - position * unit accumulative funding
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @return availableCash The available cash of the trader
     */
    function getAvailableCash(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256 availableCash)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        availableCash = account.cash.sub(account.position.wmul(perpetual.unitAccumulativeFunding));
    }

    /**
     * @dev Get the position of the trader in the perpetual
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @return position The position of the trader
     */
    function getPosition(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256 position)
    {
        position = perpetual.marginAccounts[trader].position;
    }

    /**
     * @dev Margin = available cash + position * price
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the margin
     * @return margin The margin of the trader
     */
    function getMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 margin) {
        margin = perpetual.marginAccounts[trader].position.wmul(price).add(
            getAvailableCash(perpetual, trader)
        );
    }

    /**
     * @dev Get the settleable margin of the trader in the perpetual, if the state of
     *      the perpetual is not "cleared", the settleable margin is always zero
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the settleable margin
     * @return margin The settleable margin of the trader
     */
    function getSettleableMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 margin) {
        margin = getMargin(perpetual, trader, price);
        if (margin > 0) {
            int256 rate =
                (getPosition(perpetual, trader) == 0)
                    ? perpetual.redemptionRateWithoutPosition
                    : perpetual.redemptionRateWithPosition;
            margin = margin.wmul(rate);
        } else {
            margin = 0;
        }
    }

    /**
     * @dev Available margin = margin - max(initial margin, keeper gas reward), keeper gas
     *      reward = 0 if position = 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate available margin
     * @return availableMargin The available margin of the trader
     */
    function getAvailableMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 availableMargin) {
        int256 threshold =
            getPosition(perpetual, trader) == 0
                ? 0
                : getInitialMargin(perpetual, trader, price).max(perpetual.keeperGasReward);
        availableMargin = getMargin(perpetual, trader, price).sub(threshold);
    }

    /**
     * @dev Check if the trader is initial margin safe, which means available margin >= 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the available margin
     * @return isSafe If the trader is initial margin safe
     */
    function isInitialMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        isSafe = (getAvailableMargin(perpetual, trader, price) >= 0);
    }

    /**
     * @dev Check if the trader is maintenance margin safe, which means
     *      margin >= max(maintenance margin, keeper gas reward). Keeper gas reward = 0
     *      if position = 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the maintenance margin
     * @return isSafe If the trader is maintenance margin safe
     */
    function isMaintenanceMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        int256 threshold =
            getPosition(perpetual, trader) == 0
                ? 0
                : getMaintenanceMargin(perpetual, trader, price).max(perpetual.keeperGasReward);
        isSafe = getMargin(perpetual, trader, price) >= threshold;
    }

    /**
     * @dev Check if the trader is margin safe, which means margin >= 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param price The price to calculate the margin
     * @return isSafe If the trader is margin safe
     */
    function isMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        isSafe = getMargin(perpetual, trader, price) >= 0;
    }

    /**
     * @dev Check if the account of the trader is empty, which means cash = 0 and position = 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @return isEmpty If the account of the trader is empty
     */
    function isEmptyAccount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool isEmpty)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        isEmpty = (account.cash == 0 && account.position == 0);
    }

    /**
     * @dev Update the trader's cash of the perpetual
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param deltaCash The cash to add, can be negative
     */
    function updateCash(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaCash
    ) internal {
        if (deltaCash == 0) {
            return;
        }
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = account.cash.add(deltaCash);
    }

    /**
     * @dev Update the trader's margin of the perpetual
     * @param perpetual The perpetual
     * @param trader The address of the trader
     * @param deltaPosition The position to add, can be negative
     * @param deltaCash The cash to add, can be negative
     */
    function updateMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaPosition,
        int256 deltaCash
    ) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        if (deltaPosition != 0) {
            account.position = account.position.add(deltaPosition);
        }
        if (deltaCash != 0) {
            account.cash = account.cash.add(deltaCash).add(
                perpetual.unitAccumulativeFunding.wmul(deltaPosition)
            );
        }
    }

    /**
     * @dev Reset the trader's account to empty, which means position = 0 and cash = 0
     * @param perpetual The perpetual
     * @param trader The address of the trader
     */
    function resetAccount(PerpetualStorage storage perpetual, address trader) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = 0;
        account.position = 0;
    }
}
