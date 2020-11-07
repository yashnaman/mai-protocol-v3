// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Type.sol";

library SettingImp {

    function setArgument(
        Perpetual storage perpetual,
        bytes32 entry,
        int256 value
    ) public {
        if (entry == "") {
            perpetual.settings.initialMarginRate = value;
        }
    }
}
