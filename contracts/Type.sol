// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

struct Option {
    int256 value;
    int256 minValue;
    int256 maxValue;
}

struct OraclePriceData {
    int256 price;
    uint256 time;
}

struct MarginAccount {
    int256 cashBalance;
    int256 positionAmount;
}

enum MarketState { INVALID, INITIALIZING, NORMAL, EMERGENCY, CLEARED }
enum OrderType { LIMIT, MARKET, STOP }

struct Order {
    address trader;
    address broker;
    address relayer;
    address referrer;
    address liquidityPool;
    uint256 marketIndex;
    int256 amount;
    int256 priceLimit;
    int256 minTradeAmount;
    uint256 tradeGasLimit;
    uint256 chainID;
    bytes32 data;
}

struct Receipt {
    int256 tradingValue;
    int256 tradingAmount;
    int256 lpFee;
    int256 vaultFee;
    int256 operatorFee;
    int256 referrerFee;
}

struct Core {
    bool isFinalized;
    // addresses
    address factory;
    address operator;
    address governor;
    address shareToken;
    address accessController;
    // vault
    address vault;
    int256 vaultFeeRate;
    // collateral
    bool isWrapped;
    uint256 scaler;
    address collateral;
    int256 poolCashBalance;
    int256 poolCollateral;
    // insurance fund
    int256 insuranceFund;
    int256 insuranceFundCap;
    int256 donatedInsuranceFund;
    // fee
    int256 totalClaimableFee;
    mapping(address => int256) claimableFees;
    // markets
    Market[] markets;
    // order
    mapping(bytes32 => int256) orderFilled;
    mapping(bytes32 => bool) orderCanceled;
    // funding
    uint256 fundingTime;
    uint256 priceUpdateTime;
}

struct Market {
    uint256 id;
    MarketState state;
    address oracle;
    int256 depositedCollateral;
    // prices
    OraclePriceData indexPriceData;
    OraclePriceData markPriceData;
    OraclePriceData settlementPriceData;
    // funding state
    int256 fundingRate;
    int256 unitAccumulativeFunding;
    // core parameters
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 lpFeeRate;
    int256 referrerRebateRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
    int256 insuranceFundRate;
    // ris parameters
    Option halfSpread;
    Option openSlippageFactor;
    Option closeSlippageFactor;
    Option fundingRateLimit;
    Option maxLeverage;
    // users
    int256 totalMarginWithoutPosition;
    int256 totalMarginWithPosition;
    int256 redemptionRateWithoutPosition;
    int256 redemptionRateWithPosition;
    EnumerableSetUpgradeable.AddressSet activeAccounts;
    EnumerableSetUpgradeable.AddressSet clearedTraders;
    // accounts
    mapping(address => MarginAccount) marginAccounts;
}
