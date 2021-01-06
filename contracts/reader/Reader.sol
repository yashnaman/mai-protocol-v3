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

    struct LiquidityPoolReaderResult {
        bool isInitialized;
        bool isFastCreationEnabled;
        // check Getter.sol for detail
        address[7] addresses;
        int256 vaultFeeRate;
        int256 poolCash;
        uint256 collateralDecimals;
        uint256 perpetualCount;
        uint256 fundingTime;
        PerpetualReaderResult[] perpetuals;
    }

    struct PerpetualReaderResult {
        PerpetualState state;
        address oracle;
        // check Getter.sol for detail
        int256[34] nums;
        uint256 symbol; // minimum number in the symbol service
        string underlyingAsset;
        int256 ammCashBalance;
        int256 ammPositionAmount;
    }

    function getAccountStorage(
        address liquidityPool,
        uint256 perpetualIndex,
        address account
    ) public returns (MarginAccount memory marginAccount) {
        (marginAccount.cash, marginAccount.position, , , , , , ) = ILiquidityPool(liquidityPool)
            .getMarginAccount(perpetualIndex, account);
    }

    function getLiquidityPoolStorage(address liquidityPool)
        public
        returns (LiquidityPoolReaderResult memory pool)
    {
        // pool
        uint256 perpetualCount;
        (
            pool.isInitialized,
            pool.isFastCreationEnabled,
            pool.addresses,
            pool.vaultFeeRate,
            pool.poolCash,
            pool.collateralDecimals,
            perpetualCount,
            pool.fundingTime
        ) = ILiquidityPool(liquidityPool).getLiquidityPoolInfo();
        // perpetual
        address creator = pool.addresses[0];
        address symbolService = IPoolCreator(creator).symbolService();
        pool.perpetuals = new PerpetualReaderResult[](perpetualCount);
        for (uint256 i = 0; i < perpetualCount; i++) {
            getPerpetual(pool.perpetuals[i], symbolService, liquidityPool, i);
        }
    }

    function getPerpetual(
        PerpetualReaderResult memory perp,
        address symbolService,
        address liquidityPool,
        uint256 perpetualIndex
    ) private {
        // perpetual
        (perp.state, perp.oracle, perp.nums) = ILiquidityPool(liquidityPool).getPerpetualInfo(
            perpetualIndex
        );
        // symbol
        perp.symbol = getMinSymbol(symbolService, liquidityPool, perpetualIndex);
        // underlying
        perp.underlyingAsset = IOracle(perp.oracle).underlyingAsset();
        // amm state. amm's account is the same as liquidity pool address
        (perp.ammCashBalance, perp.ammPositionAmount, , , , , , ) = ILiquidityPool(liquidityPool)
            .getMarginAccount(perpetualIndex, liquidityPool);
    }

    function getMinSymbol(
        address symbolService,
        address liquidityPool,
        uint256 perpetualIndex
    ) private view returns (uint256) {
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
