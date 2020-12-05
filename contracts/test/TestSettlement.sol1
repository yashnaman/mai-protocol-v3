// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/SettlementModule.sol";

import "../Type.sol";
import "../Settlement.sol";
import "./TestMargin.sol";

contract TestSettlement is TestMargin, Settlement {
    using SettlementModule for Core;

    constructor(address oracle) TestMargin(oracle) {
    }

    function setFee(int256 fee) public {
        _core.totalClaimableFee = fee;
    }

    function registerTrader(address trader) public {
        _core.registerTrader(trader);
    }

    function setEmergency() public {
        _enterEmergencyState();
    }

    function setClearedState() public {
        _enterClearedState();
    }
}
