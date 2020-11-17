// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library SafeCastExt {
    function toAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
