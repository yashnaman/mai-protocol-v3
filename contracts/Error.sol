// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library Error {
    string constant internal _TRADING_DEADLINE_REACHED = "trading deadline reached";
    string constant internal _INVALID_TRADING_PRICE = "invalid trading price";
    string constant internal _EXCEED_PRICE_LIMIT = "exceed price limit";
    string constant internal _ZERO_POSITION_AMOUNT = "zero position amount";
}