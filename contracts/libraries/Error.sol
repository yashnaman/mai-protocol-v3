// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library Error {
    string constant internal INVALID_TRADER_ADDRESS = "invalid trader address";
    string constant internal INVALID_TRADING_PRICE = "invalid trading price";
    string constant internal INVALID_POSITION_AMOUNT = "invalid position amount";
    string constant internal INVALID_COLLATERAL_AMOUNT = "invalid collateral amount";
    string constant internal INVALID_PRIVILEGE = "invalid privilege";

    string constant internal EXCEED_PRICE_LIMIT = "exceed price limit";
    string constant internal EXCEED_DEADLINE = "exceed deadline";
    string constant internal TRADING_DEADLINE_REACHED = "trading deadline reached";
    string constant internal PRIVILEGE_ALREADY_SET = "privilege already set";
    string constant internal PRIVILEGE_NOT_SET = "privilege already set";
    string constant internal ACCOUNT_MM_UNSAFE = "account mm unsafe";
    string constant internal ACCOUNT_IM_UNSAFE = "account im unsafe";
}