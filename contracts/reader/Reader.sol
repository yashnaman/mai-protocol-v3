// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IOracle.sol";

contract Reader {

    struct LiquidityPoolStorage {
        address operator;
        address collateral;
        address vault;
        address governor;
        address shareToken;
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
        string underlyingAsset;
        MarketState state;
        address oracle;
        int256 markPrice;
        int256 indexPrice;
        int256 unitAccumulativeFunding;
        int256 initialMarginRate;
        int256 maintenanceMarginRate;
        int256 operatorFeeRate;
        int256 lpFeeRate;
        int256 referrerRebateRate;
        int256 liquidationPenaltyRate;
        int256 keeperGasReward;
        int256 insuranceFundRate;
        int256 halfSpread;
        int256 openSlippageFactor;
        int256 closeSlippageFactor;
        int256 fundingRateLimit;
        int256 maxLeverage;
        int256 ammPositionAmount;
    }

    function getAccountStorage(
        address liquidityPool,
        uint256 marketIndex,
        address account
    ) public view returns (MarginAccount memory marginAccount) {
        (marginAccount.cashBalance, marginAccount.positionAmount) = ILiquidityPool(liquidityPool)
            .marginAccount(marketIndex, account);
    }

    function getLiquidityPoolStorage(address liquidityPool)
        public
        returns (LiquidityPoolStorage memory pool)
    {
        uint256 marketCount;
        {
            address[6] memory addresses;
            int256[7] memory nums;
            (
                addresses,
                nums,
                marketCount,
                pool.fundingTime
            ) = ILiquidityPool(liquidityPool).liquidityPoolInfo();
            pool.operator = addresses[1];
            pool.collateral = addresses[2];
            pool.vault = addresses[3];
            pool.governor = addresses[4];
            pool.shareToken = addresses[5];
            pool.vaultFeeRate = nums[0];
            pool.insuranceFundCap = nums[1];
            pool.insuranceFund = nums[2];
            pool.donatedInsuranceFund = nums[3];
            pool.totalClaimableFee = nums[4];
            pool.poolCashBalance = nums[5];
        }
        
        pool.marketStorages = new MarketStorage[](marketCount);
        for (uint256 i = 0; i < marketCount; i++) {
            {
                int256[17] memory nums;
                (
                    pool.marketStorages[i].state,
                    pool.marketStorages[i].oracle,
                    nums
                ) = ILiquidityPool(liquidityPool).marketInfo(i);
                pool.marketStorages[i].markPrice = nums[1];
                pool.marketStorages[i].indexPrice = nums[2];
                pool.marketStorages[i].unitAccumulativeFunding = nums[3];
                pool.marketStorages[i].initialMarginRate = nums[4];
                pool.marketStorages[i].maintenanceMarginRate = nums[5];
                pool.marketStorages[i].operatorFeeRate = nums[6];
                pool.marketStorages[i].lpFeeRate = nums[7];
                pool.marketStorages[i].referrerRebateRate = nums[8];
                pool.marketStorages[i].liquidationPenaltyRate = nums[9];
                pool.marketStorages[i].keeperGasReward = nums[10];
                pool.marketStorages[i].insuranceFundRate = nums[11];
                pool.marketStorages[i].halfSpread = nums[12];
                pool.marketStorages[i].openSlippageFactor = nums[13];
                pool.marketStorages[i].closeSlippageFactor = nums[14];
                pool.marketStorages[i].fundingRateLimit = nums[15];
                pool.marketStorages[i].maxLeverage = nums[16];
            }
            pool.marketStorages[i].underlyingAsset = IOracle(pool.marketStorages[i].oracle).underlyingAsset();
            (
                ,
                pool.marketStorages[i].ammPositionAmount
            ) = ILiquidityPool(liquidityPool).marginAccount(i, liquidityPool);
        }
    }
}
