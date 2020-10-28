// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Storage.sol";

library AMM {

    function updateFundingRate(
        Storage.Perpetual storage perpetual
    ) public {
        // update funding rate.

    }

    function determineDeltaCashBalance(
        Storage.Perpetual storage perpetual,
        int256 positionAmount
    ) public returns (int256, int256) {
        Storage.MarginAccount memory account = perpetual.traderAccounts(address(this));
        if (positionAmount > 0) {
            _buy()
        } else {
            _sell()
        }
        return (0, 0);
    }

    function addLiquidatity(
        Storage.Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function removeLiquidatity(
        Storage.Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function _buy() internal {

    }

    ...
}