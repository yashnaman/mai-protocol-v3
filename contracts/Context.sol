// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract Context {
    function _self() internal virtual view returns (address) {
        return address(this);
    }

    function _now() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    function _msgSender() internal virtual view returns (address) {
        return msg.sender;
    }

    bytes32[50] private __gap;
}
