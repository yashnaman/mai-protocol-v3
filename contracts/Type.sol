// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

// struct Context {
//     address taker;
//     address maker;
//     MarginAccount takerAccount;
//     MarginAccount makerAccount;
//     int256 lpFee;
//     int256 vaultFee;
//     int256 operatorFee;
//     int256 tradingPrice;
//     // 不含fee
//     int256 deltaMargin;
// }

struct Settings {
    int256 reservedMargin;
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 vaultFeeRate;
    int256 operatorFeeRate;
    int256 liquidityProviderFeeRate;
    int256 liquidationPenaltyRate1;
    int256 liquidationPenaltyRate2;
    int256 liquidationGasReserve;
    int256 halfSpreadRate;
    int256 beta1;
    int256 beta2;
    int256 baseFundingRate;
    int256 targetLeverage;
}

struct FundingState {
    int256 unitAccumulatedFundingLoss;
    int256 lastIndexPrice;
    int256 lastFundingRate;
    uint256 lastFundingTime;
}

struct OraclePrice {
    int256 price;
    uint256 timestamp;
}

struct MarginAccount {
    int256 cashBalance;
    int256 positionAmount;
    int256 entryFundingLoss;
}

struct LiquidityProviderAccount {
    int256 entryInsuranceFund;
}

struct AccessControl {
    uint256 privileges;
}