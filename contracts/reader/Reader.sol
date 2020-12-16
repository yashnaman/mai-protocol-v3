// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "../interface/ILiquidityPool.sol";

contract Reader {

    struct LiquidityPoolStorage {
        address operator;
        address collateral;
        address shareToken;
        address governor;
        address vault;
        int256 vaultFeeRate;
        int256 insuranceFundCap;

        int256 insuranceFund;
        int256 donatedInsuranceFund;
        int256 totalClaimableFee;
        int256 poolCashBalance;
        uint256 fundingTime;
        MarketStorage[] marketStorages;
    }

    struct MarketStorage {
        MarketState state;
        string underlyingAsset;
        address oracle;
        int256 markPrice;
        int256 indexPrice;
        int256 initialMarginRate;
        int256 maintenanceMarginRate;
        int256 operatorFeeRate;
        int256 vaultFeeRate;
        int256 lpFeeRate;
        int256 referrerRebateRate;
        int256 liquidationPenaltyRate;
        int256 keeperGasReward;
        int256 insuranceFundRate;
        int256 fundingRate;
        int256 unitAccumulativeFunding;
        int256 halfSpread;
        int256 openSlippageFactor;
        int256 closeSlippageFactor;
        int256 fundingRateLimit;
        int256 maxLeverage;
        MarginAccount ammAccountStorage;
    }

    function getAccountStorage(
        address liquidityPool,
        uint256 marketIndex,
        address account
    ) public view returns (MarginAccount memory marginAccount) {
        (marginAccount.cashBalance, marginAccount.positionAmount) = ILiquidityPool(liquidityPool)
            .marginAccount(marketIndex, account);
    }

    /*
    [00] operatorAddress
    [01] collateralTokenAddress
    [02] shareTokenAddress
    [03] governorAddress
    [04] vaultAddress
    [05] vaultFeeRate
    [06] insuranceFund
    [07] insuranceFundCap
    [08] donatedInsuranceFund
    [09] totalClaimableFee
    [10] poolCashBalance
    [11] fundingTime
    [12] marketCount
    [13 + market * 19]
      [00] oracleAddress
      [01] initialMarginRate
      [02] maintenanceMarginRate
      [03] operatorFeeRate
      [04] lpFeeRate
      [05] referrerRebateRate
      [06] liquidationPenaltyRate
      [07] keeperGasReward
      [08] insuranceFundRate
      [09] state
      [10] markPrice
      [11] indexPrice
      [12] unitAccumulativeFunding
      [13] halfSpread
      [14] openSlippageFactor
      [15] closeSlippageFactor
      [16] fundingRateLimit
      [17] maxLeverage
      [18] ammPositionAmount
    */
    function getLiquidityPoolStorage(address liquidityPool)
        public
        returns (LiquidityPoolStorage memory pool)
    {
        uint256 marketCount;
        (
            ,
            pool.operator,
            pool.collateral,
            pool.vault,
            pool.vaultFeeRate,
            pool.insuranceFundCap,
            marketCount
        ) = ILiquidityPool(liquidityPool).liquidityPoolInfo();
        (
            pool.insuranceFund,
            pool.donatedInsuranceFund,
            pool.totalClaimableFee,
            pool.poolCashBalance,
            ,
            pool.fundingTime
        ) = ILiquidityPool(liquidityPool).liquidityPoolState();
        pool.shareToken = ILiquidityPool(liquidityPool).shareToken();
        pool.governor = ILiquidityPool(liquidityPool).governor();
        pool.marketStorages = new MarketStorage[](marketCount);
        for (uint256 i = 0; i < marketCount; i++) {
        //     MarketStorage memory marketStorage;
        //     int256[8] memory coreParameters;
        //     int256[5] memory riskParameters;
        //     (
        //         marketStorage.state,
        //         marketStorage.oracle,
        //         marketStorage.markPrice,
        //         marketStorage.indexPrice,
        //         marketStorage.unitAccumulativeFunding,
        //         marketStorage.fundingRate,
        //         coreParameters,
        //         riskParameters
        //     ) = pool.marketInfo(i);

        // marketStorage.underlyingAsset = IOracle(marketStorage.oracle).underlyingAsset();
        // marketStorage.initialMarginRate = coreParameters[0];
        // marketStorage.maintenanceMarginRate = coreParameters[1];
        // marketStorage.operatorFeeRate = coreParameters[2];
        // marketStorage.lpFeeRate = coreParameters[3];
        // marketStorage.referrerRebateRate = coreParameters[4];
        // marketStorage.liquidationPenaltyRate = coreParameters[5];
        // marketStorage.keeperGasReward = coreParameters[6];
        // marketStorage.insuranceFundRate = coreParameters[7];
        // marketStorage.halfSpread = riskParameters[0];
        // marketStorage.openSlippageFactor = riskParameters[1];
        // marketStorage.closeSlippageFactor = riskParameters[2];
        // marketStorage.fundingRateLimit = riskParameters[3];
        // marketStorage.maxLeverage = riskParameters[4];
        // marketStorage.ammAccountStorage = getAccountStorage(liquidityPool, i, liquidityPool);
        // liquidityPoolStorage.marketStorages[i] = marketStorage;
        }
    }
}
