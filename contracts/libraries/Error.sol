// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library Error {
    string internal constant INVALID_TRADER_ADDRESS = "invalid trader address";
    string internal constant INVALID_TRADING_PRICE = "invalid trading price";
    string
        internal constant INVALID_POSITION_AMOUNT = "invalid position amount";
    string
        internal constant INVALID_COLLATERAL_AMOUNT = "invalid collateral amount";
    string internal constant INVALID_PRIVILEGE = "invalid privilege";

    string internal constant EXCEED_PRICE_LIMIT = "exceed price limit";
    string internal constant EXCEED_DEADLINE = "exceed deadline";
    string
        internal constant TRADING_DEADLINE_REACHED = "trading deadline reached";
    string internal constant PRIVILEGE_ALREADY_SET = "privilege already set";
    string internal constant PRIVILEGE_NOT_SET = "privilege already set";
    string internal constant ACCOUNT_MM_UNSAFE = "account mm unsafe";
    string internal constant ACCOUNT_IM_UNSAFE = "account im unsafe";
}
