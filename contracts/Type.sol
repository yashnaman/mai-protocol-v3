// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

enum Side {LONG, SHORT, FLAT}

struct Context {
    address taker;
    address maker;
    MarginAccount takerAccount;
    MarginAccount makerAccount;
    int256 lpFee;
    int256 vaultFee;
    int256 operatorFee;
    int256 tradingPrice;
    // 不含fee
    int256 deltaMargin;
}

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

struct MarginAccount {
    int256 cashBalance;
    int256 positionAmount;
    int256 entrySocialLoss;
    int256 entryFundingLoss;
}

struct LiquidationProviderAccount {
    int256 entryInsuranceFund;
}

struct State {
    bool emergency;
    bool shutdown;
    int256 markPrice; // slow
    int256 indexPrice; // fast
    int256 unitSocialLoss;
    int256 unitAccumulatedFundingLoss;
    int256 totalPositionAmount;
    int256 insuranceFund;
    uint256 lastFundingTime;
    int256 lastIndexPrice;
    int256 lastFundingRate;
}

struct Perpetual {
    string symbol;
    address vault;
    address parent;
    address operator;
    address oracle;

    State state;
    Settings settings;
    mapping(address => MarginAccount) traderAccounts;
    mapping(address => LiquidationProviderAccount) lpAccounts;
}
