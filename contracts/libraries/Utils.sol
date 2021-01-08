// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "./SafeMathExt.sol";

library Utils {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    /*
     * @dev Check if two numbers have the same sign,
     *      zero has the same sign with any number
     */
    function hasTheSameSign(int256 x, int256 y) internal pure returns (bool) {
        if (x == 0 || y == 0) {
            return true;
        }
        return (x ^ y) >> 255 == 0;
    }

    /*
     * @dev Get sign of a number
     */
    function extractSign(int256 x) internal pure returns (int256) {
        return x >= 0 ? int256(1) : int256(-1);
    }

    /*
     * @dev Split delta to two numbers. Amount will be close to zero if added first.
     *      Amount will be away from zero if added second(after added first).
     *      2, 1 => 0, 1; 2, -1 => -1, 0; 2, -3 => -2, -1;
     */
    function splitAmount(int256 amount, int256 delta) internal pure returns (int256, int256) {
        if (Utils.hasTheSameSign(amount, delta)) {
            return (0, delta);
        } else if (amount.abs() >= delta.abs()) {
            return (delta, 0);
        } else {
            return (amount.neg(), amount.add(delta));
        }
    }

    /*
     * @dev Check if amount will be away from zero or cross zero if added delta.
     *      2, 1 => true; 2, -1 => false; 2, -3 => true;
     */
    function isOpen(int256 amount, int256 delta) internal pure returns (bool) {
        return Utils.hasTheSameSign(amount, delta) || amount.abs() < delta.abs();
    }

    /*
     * @dev Get id of current chain
     */
    function chainID() internal pure returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}
