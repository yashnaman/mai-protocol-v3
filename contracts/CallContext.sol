// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract CallContext {

    function _self() internal view virtual returns (address) {
        return address(this);
    }

    function _now() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    bytes32[50] private __gap;
}
