// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library Bitwise {
    function test(uint256 value, uint256 bit) internal pure returns (bool) {
        return value & bit > 0;
    }

    function set(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value | bit;
    }

    function clean(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value & (~bit);
    }
}
