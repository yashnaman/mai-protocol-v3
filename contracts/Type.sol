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

struct CoreParameter {
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 vaultFeeRate;
    int256 lpFeeRate;
    int256 ReferRebateReeRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
}

struct RiskParameter {
    Option halfSpreadRate;
    Option beta1;
    Option beta2;
    Option fundingRateCoefficent;
    Option virtualLeverage;
}
