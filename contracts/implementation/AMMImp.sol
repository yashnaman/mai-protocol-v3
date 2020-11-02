// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

library AMMImp {

    function updateFundingRate(
        Perpetual storage perpetual,
        Context memory context
    ) public {
        // update funding rate.

    }

    function determineDeltaCashBalance(
        Perpetual storage perpetual,
        int256 positionAmount
    ) public returns (int256, int256) {
        // Storage.MarginAccount memory account = perpetual.traderAccounts(address(this));
        // if (positionAmount > 0) {
        //     _buy()
        // } else {
        //     _sell()
        // }
        return (0, 0);
    }

    function addLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function removeLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    // function _buy() internal {

    // }

    // ...
}