// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract Context {

    function _self() internal view virtual returns (address) {
        return address(this);
    }

    function _now() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
