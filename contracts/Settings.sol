// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Storage.sol";

library Settings {

    function setArgument(
        Storage.Perpetual storage perpetual,
        bytes32 entry,
        int256 value
    ) public {
        if (entry == "") {
            perpetual.settings.initialMarginRate = value;
        }
    }
}
