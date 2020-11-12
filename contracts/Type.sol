// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

struct Option {
    int256 value;
    int256 minValue;
    int256 maxValue;
}

struct FundingState {
    int256 unitAccFundingLoss;
    int256 fundingRate;
    int256 lastIndexPrice;
    int256 lastFundingRate;
    uint256 lastFundingTime;
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

struct AccessControl {
    uint256 privileges;
}

struct Progress {
    int256 currentValue;
    int256 totalValue;
}

struct RiskParameter {
    Option halfSpreadRate;
    Option beta1;
    Option beta2;
    Option FundingRateCoefficent;
    Option virtualLeverage;
}
