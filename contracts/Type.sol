// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

struct Option {
    int256 value;
    int256 minValue;
    int256 maxValue;
}

struct FundingState {
    int256 unitAccumulatedFundingLoss;
    int256 fundingRate;
    int256 indexPrice;
    uint256 fundingTime;
}

struct OraclePriceData {
    int256 price;
    uint256 timestamp;
}

struct MarginAccount {
    int256 cashBalance;
    int256 positionAmount;
    int256 entryFundingLoss;
}

struct CoreParameter {
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 vaultFeeRate;
    int256 lpFeeRate;
    int256 referrerRebateRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
}

struct RiskParameter {
    Option halfSpreadRate;
    Option beta1;
    Option beta2;
    Option fundingRateCoefficient;
    Option targetLeverage;
}

enum ActionOnFailure {IGNORE, REVERT}
enum OrderType {LIMIT, MARKET, STOP}

struct Signature {
    bytes32 config;
    bytes32 r;
    bytes32 s;
}

struct Order {
    address trader;
    address broker;
    address relayer;
    address perpetual;
    address referrer;
    int256 amount;
    int256 priceLimit;
    uint64 deadline;
    uint32 version;
    OrderType orderType;
    bool closeOnly;
    uint64 salt;
    uint256 chainID;
    Signature signature;
}
