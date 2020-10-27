// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.1;

import "../libs/LibMath.sol";

contract TestLibMath {

    function mostSignificantBit(uint256 x) public pure returns (uint8) {
        return LibMath.mostSignificantBit(x);
    }

    function sqrt(uint256 y) public pure returns (uint256) {
        return LibMath.sqrt(y);
    }
}
