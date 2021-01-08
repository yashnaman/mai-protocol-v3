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
     * @dev Get initial margin of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate initial margin
     * @return initialMargin The initial margin
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
     * @dev Get maintenance margin of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate maintenance margin
     * @return maintenanceMargin The maintenance margin
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
            .abs()
            .max(perpetual.keeperGasReward);
    }

    /**
     * @dev Get available cash of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @return availableCash The available cash
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
     * @dev Get position of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @return position The position
     */
    function getPosition(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256 position)
    {
        position = perpetual.marginAccounts[trader].position;
    }

    /**
     * @dev Get margin of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate margin
     * @return margin The margin
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
     * @dev Get settleable margin of trader in perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate settleable margin
     * @return margin The settleable margin
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
     * @dev Get available margin of given account.
     * @param perpetual The perpetual storage reference
     * @param trader The address of trader
     * @param price The price to calculate margin / initial margin
     * @return availableMargin Available margin of trader
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
     * @dev Check if trader is initial margin safe
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate initial margin
     * @return isSafe True if trader is initial margin safe
     */
    function isInitialMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        isSafe = (getAvailableMargin(perpetual, trader, price) >= 0);
    }

    /**
     * @dev Check if trader is maintenance margin safe
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate maintenance margin
     * @return isSafe If trader is maintenance margin safe
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
     * @dev Check if trader is margin safe
     * @param perpetual The perpetual
     * @param trader The trader
     * @param price The price to calculate margin
     * @return isSafe If trader is margin safe
     */
    function isMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        isSafe = getMargin(perpetual, trader, price) >= 0;
    }

    /**
     * @dev Check if account of trader is empty
     * @param perpetual The perpetual
     * @param trader The trader
     * @return isEmpty If account of trader is empty
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
     * @dev Update trader's cash of perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param deltaCash The delta cash
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
     * @dev Update trader's margin of perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     * @param deltaPosition The delta position
     * @param deltaCash The delta cash
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
     * @dev Reset trader's margin of perpetual
     * @param perpetual The perpetual
     * @param trader The trader
     */
    function resetAccount(PerpetualStorage storage perpetual, address trader) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = 0;
        account.position = 0;
    }
}
