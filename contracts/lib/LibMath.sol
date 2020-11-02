// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.4;

library LibMath {

    // 0 ~ 1 => 0, 2 ~ 3 => 1, 4 ~ 7 => 2, 8 ~ 15 => 3
    // 606 ~ 672 gas
    function mostSignificantBit(uint256 x) internal pure returns (uint8) {
        uint256 t;
        uint8 r;
        if ((t = (x >> 128)) > 0) { x = t; r += 128; }
        if ((t = (x >> 64)) > 0) { x = t; r += 64; }
        if ((t = (x >> 32)) > 0) { x = t; r += 32; }
        if ((t = (x >> 16)) > 0) { x = t; r += 16; }
        if ((t = (x >> 8)) > 0) { x = t; r += 8; }
        if ((t = (x >> 4)) > 0) { x = t; r += 4; }
        if ((t = (x >> 2)) > 0) { x = t; r += 2; }
        if ((t = (x >> 1)) > 0) { x = t; r += 1; }
        return r;
    }

    // https://en.wikipedia.org/wiki/Integer_square_root
    function sqrt(int256 y) internal pure returns (int256) {
        require(y >= 0, "negative sqrt");
        if (y < 3) {
            return (y + 1) / 2;
        }

        // binary estimate
        // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_estimates
        int256 next;
        {
            uint8 n = mostSignificantBit(uint256(y));
            n = (n + 1) / 2;
            next = int256((1 << (n - 1)) + (uint256(y) >> (n + 1)));
        }

        // modified babylonian method
        // https://github.com/Uniswap/uniswap-v2-core/blob/v1.0.1/contracts/libraries/Math.sol#L11
        int256 z = y;
        while (next < z) {
            z = next;
            next = (next + y / next) >> 1;
        }
        return z;
    }
}