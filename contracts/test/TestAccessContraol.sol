// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../AccessControl.sol";

contract TestAccessControl is AccessControl {
    function privilege(address owner, address trader) public view returns (uint256) {
        return _core.accessControls[msg.sender][trader];
    }

    function deposit(address trader) public auth(trader, PRIVILEGE_DEPOSTI) {}

    function withdraw(address trader) public auth(trader, PRIVILEGE_WITHDRAW) {}

    function trade(address trader) public auth(trader, PRIVILEGE_TRADE) {}
}
