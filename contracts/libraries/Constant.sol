// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library Constant {
    address internal constant INVALID_ADDRESS = address(0);
    int256 internal constant SIGNED_ONE = 10**18;
    uint256 internal constant UNSIGNED_ONE = 10**18;

    uint256 internal constant PRIVILEGE_DEPOSTI = 0x1;
    uint256 internal constant PRIVILEGE_WITHDRAW = 0x2;
    uint256 internal constant PRIVILEGE_TRADE = 0x4;
    uint256 internal constant PRIVILEGE_GUARD = PRIVILEGE_DEPOSTI |
        PRIVILEGE_WITHDRAW |
        PRIVILEGE_TRADE;
}
