// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

enum ActionOnFailure {IGNORE, REVERT}
enum OrderType {LIMIT, MARKET, STOP}

struct Order {
    address trader;
    address broker;
    address perpetual;
    int256 amount;
    int256 priceLimit;
    uint64 deadline;
    uint32 version;
    OrderType orderType;
    bool closeOnly;
    uint64 salt;
    uint256 chainID;
}
