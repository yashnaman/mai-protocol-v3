// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../LiquidityPool.sol";

contract LiquidityPoolV2 is LiquidityPool {
    function getMagicNumber() public pure returns (uint256) {
        return 6788;
    }

    bytes[50] private __gap;
}
