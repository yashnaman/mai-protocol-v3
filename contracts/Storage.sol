// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract Storage {

    struct Context {
        MarginAccount takerAccount;
        MarginAccount makerAccount;
        int256 lpFee;
        int256 vaultFee;
        int256 operatorFee;
        int256 tradingPrice;
    }

    struct Settings {
        int256 minimalMargin;
        int256 initialMarginRate;
        int256 maintenanceMarginRate;
        int256 vaultFeeRate;
        int256 operatorFeeRate;
        int256 liquidatorPenaltyRate;
        int256 liquidationGasReserve;
        int256 fundPenaltyRate;
        int256 lpFee;
    }

    struct AMMState {

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
        int256 markPrice;
        int256 unitSocialLoss;
        int256 unitAccumulatedFundingLoss;
        int256 totalPositionAmount;
        int256 insuranceFund;
    }

    struct Perpetual {
        string symbol;
        address vault;
        address operator;
        address oracle;
        State state;
        AMMState ammState;
        Settings settings;
        MarginAccount ammAccount;
        mapping (address => MarginAccount) traderAccounts;
        mapping (address => LiquidationProviderAccount) lpAccounts;
    }

}