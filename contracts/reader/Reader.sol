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
        PerpetualStorage[] perpetualStorages;
    }

    struct PerpetualStorage {
        string underlyingAsset;
        PerpetualState state;
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
        int256 ammMaxLeverage;
        int256 ammCashBalance;
        int256 ammPositionAmount;
    }

    function getAccountStorage(
        address liquidityPool,
        uint256 perpetualIndex,
        address account
    ) public view returns (MarginAccount memory marginAccount) {
        (marginAccount.cashBalance, marginAccount.positionAmount) = ILiquidityPool(liquidityPool)
            .marginAccount(perpetualIndex, account);
    }

    function getLiquidityPoolStorage(address liquidityPool)
        public
        returns (LiquidityPoolStorage memory pool)
    {
        uint256 perpetualCount;
        {
            address[6] memory addresses;
            int256[7] memory nums;
            (addresses, nums, perpetualCount, pool.fundingTime) = ILiquidityPool(liquidityPool)
                .liquidityPoolInfo();
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

        pool.perpetualStorages = new PerpetualStorage[](perpetualCount);
        for (uint256 i = 0; i < perpetualCount; i++) {
            {
                int256[17] memory nums;
                (
                    pool.perpetualStorages[i].state,
                    pool.perpetualStorages[i].oracle,
                    nums
                ) = ILiquidityPool(liquidityPool).perpetualInfo(i);
                pool.perpetualStorages[i].markPrice = nums[1];
                pool.perpetualStorages[i].indexPrice = nums[2];
                pool.perpetualStorages[i].unitAccumulativeFunding = nums[3];
                pool.perpetualStorages[i].initialMarginRate = nums[4];
                pool.perpetualStorages[i].maintenanceMarginRate = nums[5];
                pool.perpetualStorages[i].operatorFeeRate = nums[6];
                pool.perpetualStorages[i].lpFeeRate = nums[7];
                pool.perpetualStorages[i].referrerRebateRate = nums[8];
                pool.perpetualStorages[i].liquidationPenaltyRate = nums[9];
                pool.perpetualStorages[i].keeperGasReward = nums[10];
                pool.perpetualStorages[i].insuranceFundRate = nums[11];
                pool.perpetualStorages[i].halfSpread = nums[12];
                pool.perpetualStorages[i].openSlippageFactor = nums[13];
                pool.perpetualStorages[i].closeSlippageFactor = nums[14];
                pool.perpetualStorages[i].fundingRateLimit = nums[15];
                pool.perpetualStorages[i].ammMaxLeverage = nums[16];
            }
            pool.perpetualStorages[i].underlyingAsset = IOracle(pool.perpetualStorages[i].oracle)
                .underlyingAsset();
            (
                pool.perpetualStorages[i].ammCashBalance,
                pool.perpetualStorages[i].ammPositionAmount
            ) = ILiquidityPool(liquidityPool).marginAccount(i, liquidityPool);
        }
    }
}
