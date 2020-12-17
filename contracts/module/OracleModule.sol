// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../interface/IOracle.sol";

import "../Type.sol";

library OracleModule {
    function updatePrice(LiquidityPoolStorage storage liquidityPool, uint256 currentTime) internal {
        if (liquidityPool.priceUpdateTime >= currentTime) {
            return;
        }
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updatePrice(liquidityPool.perpetuals[i]);
        }
        liquidityPool.priceUpdateTime = currentTime;
    }

    function updatePrice(PerpetualStorage storage perpetual) internal {
        // no longer update price after emergency
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        updatePriceData(perpetual.markPriceData, IOracle(perpetual.oracle).priceTWAPLong);
        updatePriceData(perpetual.indexPriceData, IOracle(perpetual.oracle).priceTWAPShort);
    }

    function markPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.markPriceData.price
                : perpetual.settlementPriceData.price;
    }

    function indexPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.indexPriceData.price
                : perpetual.settlementPriceData.price;
    }

    // prettier-ignore
    function updatePriceData(
        OraclePriceData storage priceData,
        function() external returns (int256, uint256) priceGetter
    ) internal {
        (int256 price, uint256 time) = priceGetter();
        if (time != priceData.time) {
            priceData.price = price;
            priceData.time = time;
        }
    }

    function freezeOraclePrice(PerpetualStorage storage perpetual) public {
        perpetual.settlementPriceData = perpetual.indexPriceData;
    }
}
