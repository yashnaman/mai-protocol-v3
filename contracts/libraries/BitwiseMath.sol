// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library BitwiseMath {
    /**
     * @dev Check if value is 1 in bit position
     * @param value The value
     * @param bit The bit, should be 2^n
     * @return bool If value is 1 in bit position
     */
    function test(uint256 value, uint256 bit) internal pure returns (bool) {
        return value & bit > 0;
    }

    /**
     * @dev Set value to 1 in bit position
     * @param value The value
     * @param bit The bit, should be 2^n
     * @return uint256 The modified value
     */
    function set(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value | bit;
    }

    /**
     * @dev Set value to 0 in bit position
     * @param value The value
     * @param bit The bit, should be 2^n
     * @return uint256 The modified value
     */
    function clean(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value & (~bit);
    }
}
