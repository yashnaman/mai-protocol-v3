// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IOracle.sol";
import "../interface/IPoolCreator.sol";
import "../interface/ISymbolService.sol";
import "../interface/ISymbolService.sol";
import "../libraries/SafeMathExt.sol";

contract Reader {
    using SafeMathExt for uint256;

    struct LiquidityPoolStorage {
        address operator;
        address collateralToken;
        address vault;
        address governor;
        address shareToken;
        int256 vaultFeeRate;
        int256 poolCash;
        uint256 fundingTime;
        bool isInitialized;
        bool isFastCreationEnabled;
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
        int256 insuranceFundCap;
        int256 insuranceFund;
        int256 donatedInsuranceFund;
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
        (marginAccount.cash, marginAccount.position) = ILiquidityPool(liquidityPool)
            .getMarginAccount(perpetualIndex, account);
    }

    function getLiquidityPoolStorage(address liquidityPool)
        public
        returns (LiquidityPoolStorage memory pool)
    {
        address creator;
        uint256 perpetualCount;
        {
            address[6] memory addresses;
            int256[2] memory nums;
            bool isInitialized;
            bool isFastCreationEnabled;
            (
                addresses,
                nums,
                perpetualCount,
                pool.fundingTime,
                isInitialized,
                isFastCreationEnabled
            ) = ILiquidityPool(liquidityPool).getLiquidityPoolInfo();
            creator = addresses[0];
            pool.operator = addresses[1];
            pool.collateralToken = addresses[2];
            pool.vault = addresses[3];
            pool.governor = addresses[4];
            pool.shareToken = addresses[5];
            pool.vaultFeeRate = nums[0];
            pool.poolCash = nums[1];
            pool.isInitialized = isInitialized;
            pool.isFastCreationEnabled = isFastCreationEnabled;
        }
        address symbolService = IPoolCreator(creator).symbolService();

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
            int256[20] memory nums;
            (perp.state, perp.oracle, nums) = ILiquidityPool(liquidityPool).getPerpetualInfo(
                perpetualIndex
            );
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
            perp.insuranceFundCap = nums[12];
            perp.insuranceFund = nums[13];
            perp.donatedInsuranceFund = nums[14];
            perp.halfSpread = nums[15];
            perp.openSlippageFactor = nums[16];
            perp.closeSlippageFactor = nums[17];
            perp.fundingRateLimit = nums[18];
            perp.ammMaxLeverage = nums[19];
        }
        // underlying
        perp.underlyingAsset = IOracle(perp.oracle).underlyingAsset();
        // amm
        (perp.ammCashBalance, perp.ammPositionAmount) = ILiquidityPool(liquidityPool)
            .getMarginAccount(perpetualIndex, liquidityPool);
        // symbol
        perp.symbol = getMinSymbol(symbolService, liquidityPool, perpetualIndex);
    }

    function getMinSymbol(
        address symbolService,
        address liquidityPool,
        uint256 perpetualIndex
    ) private returns (uint256) {
        uint256[] memory symbols;
        symbols = ISymbolService(symbolService).getSymbols(liquidityPool, perpetualIndex);
        uint256 symbolLength = symbols.length;
        require(symbolLength >= 1, "symbol not found");
        uint256 minSymbol = type(uint256).max;
        for (uint256 i = 0; i < symbolLength; i++) {
            minSymbol = minSymbol.min(symbols[i]);
        }
        return minSymbol;
    }
}
