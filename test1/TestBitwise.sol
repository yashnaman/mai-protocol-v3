// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../libraries/Bitwise.sol";

contract TestBitwise {
    function test(uint256 value, uint256 bit) public pure returns (bool) {
        return Bitwise.test(value, bit);
    }

    function set(uint256 value, uint256 bit) public pure returns (uint256) {
        return Bitwise.set(value, bit);
    }

    function clean(uint256 value, uint256 bit) public pure returns (uint256) {
        return Bitwise.clean(value, bit);
    }
}
