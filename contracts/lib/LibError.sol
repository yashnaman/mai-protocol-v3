// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library LibError {
    string constant internal TRADING_DEADLINE_REACHED = "trading deadline reached";
    string constant internal INVALID_TRADING_PRICE = "invalid trading price";
    string constant internal EXCEED_PRICE_LIMIT = "exceed price limit";
    string constant internal INVALID_POSITION_AMOUNT = "invalid position amount";
    string constant internal INVALID_COLLATERAL_AMOUNT = "invalid collateral amount";
    string constant internal PRIVILEGE_ALREADY_SET = "privilege already set";
    string constant internal PRIVILEGE_NOT_SET = "privilege already set";
}