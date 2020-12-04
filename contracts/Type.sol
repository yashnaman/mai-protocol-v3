// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

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
    int256 entryFunding;
}

enum State { NORMAL, EMERGENCY, CLEARED }
enum ActionOnFailure { IGNORE, REVERT }
enum OrderType { LIMIT, MARKET, STOP }

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
    bytes32 data;
    uint256 chainID;
}

struct Receipt {
    int256 tradingValue;
    int256 tradingAmount;
    int256 lpFee;
    int256 vaultFee;
    int256 operatorFee;
    int256 referrerFee;
    int256 takerOpeningAmount;
    int256 makerOpeningAmount;
    int256 takerClosingAmount;
    int256 makerClosingAmount;
    int256 takerFundingLoss;
    int256 makerFundingLoss;
}

struct Core {
    // ========================== SHARED PART
    // addresses
    address factory;
    address vault;
    address operator;
    // collateral
    bool isWrapped;
    uint256 scaler;
    address collateral;
    // prices
    address oracle;
    uint256 priceUpdateTime;
    OraclePriceData indexPriceData;
    OraclePriceData markPriceData;
    OraclePriceData settlePriceData;
    // state
    State state;
    // insurance fund
    int256 insuranceFund;
    int256 donatedInsuranceFund;
    // funding state
    int256 fundingRate;
    int256 unitAccumulativeFunding;
    uint256 fundingTime;
    // core parameters
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 vaultFeeRate;
    int256 lpFeeRate;
    int256 referrerRebateRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
    int256 insuranceFundCap; // 到达cap之后，分给lp
    int256 insuranceFundRate; // 每一笔罚金都要抽这么多到fund
    // ris parameters
    Option halfSpreadRate;
    Option beta1;
    Option beta2;
    Option fundingRateCoefficient;
    Option targetLeverage;
    // accounts
    mapping(address => MarginAccount) marginAccounts;
    // fee
    int256 totalClaimableFee;
    mapping(address => int256) claimableFees;
    // users
    int256 clearingPayout;
    int256 totalMarginWithoutPosition;
    int256 totalMarginWithPosition;
    int256 redemptionRateWithoutPosition;
    int256 redemptionRateWithPosition;
    EnumerableSet.AddressSet registeredTraders;
    EnumerableSet.AddressSet clearedTraders;
    // filled
    mapping(bytes32 => int256) orderFilled;
    mapping(bytes32 => bool) orderCanceled;
    // access control
    mapping(address => mapping(address => uint256)) accessControls;
}
