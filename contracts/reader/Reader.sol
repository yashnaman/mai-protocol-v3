// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IOracle.sol";
import "../interface/IFactory.sol";
import "../interface/ISymbolService.sol";
import "../interface/ISymbolService.sol";
import "../libraries/SafeMathExt.sol";

contract Reader {
    using SafeMathExt for uint256;

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
        uint256 symbol; // minimum number in the symbol service
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
        address creator;
        uint256 perpetualCount;
        {
            address[6] memory addresses;
            int256[7] memory nums;
            (addresses, nums, perpetualCount, pool.fundingTime) = ILiquidityPool(liquidityPool)
                .liquidityPoolInfo();
            creator = addresses[0];
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
        address symbolService = IFactory(creator).symbolService();

        pool.perpetualStorages = new PerpetualStorage[](perpetualCount);
        for (uint256 i = 0; i < perpetualCount; i++) {
            getPerpetual(pool.perpetualStorages[i], symbolService, liquidityPool, i);
        }
    }

    function getPerpetual(
        PerpetualStorage memory perp,
        address symbolService,
        address liquidityPool,
        uint256 perpetualIndex
    ) private {
        // perpetual
        {
            int256[17] memory nums;
            (
                perp.state,
                perp.oracle,
                nums
            ) = ILiquidityPool(liquidityPool).perpetualInfo(perpetualIndex);
            perp.markPrice = nums[1];
            perp.indexPrice = nums[2];
            perp.unitAccumulativeFunding = nums[3];
            perp.initialMarginRate = nums[4];
            perp.maintenanceMarginRate = nums[5];
            perp.operatorFeeRate = nums[6];
            perp.lpFeeRate = nums[7];
            perp.referrerRebateRate = nums[8];
            perp.liquidationPenaltyRate = nums[9];
            perp.keeperGasReward = nums[10];
            perp.insuranceFundRate = nums[11];
            perp.halfSpread = nums[12];
            perp.openSlippageFactor = nums[13];
            perp.closeSlippageFactor = nums[14];
            perp.fundingRateLimit = nums[15];
            perp.ammMaxLeverage = nums[16];
        }
        // underlying
        perp.underlyingAsset = IOracle(perp.oracle)
            .underlyingAsset();
        // amm
        (
            perp.ammCashBalance,
            perp.ammPositionAmount
        ) = ILiquidityPool(liquidityPool).marginAccount(perpetualIndex, liquidityPool);
        // symbol
        perp.symbol = getMinSymbol(symbolService, liquidityPool, perpetualIndex);
    }

    function getMinSymbol(
        address symbolService,
        address liquidityPool,
        uint256 perpetualIndex
    ) private returns (uint256)
    {
        uint256[] memory symbols;
        symbols = ISymbolService(symbolService).getSymbols(liquidityPool, perpetualIndex);
        uint256 symbolLength = symbols.length;
        require(symbolLength>= 1, "symbol not found");
        uint256 minSymbol = type(uint256).max;
        for (uint256 i = 0; i < symbolLength; i++) {
            minSymbol = minSymbol.min(symbols[i]);
        }
        return minSymbol;
    }
}
