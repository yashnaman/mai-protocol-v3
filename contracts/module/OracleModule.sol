// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../interface/IOracle.sol";

import "../Type.sol";

library OracleModule {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function updatePrice(Core storage core, uint256 currentTime) internal {
        uint256 count = core.marketIDs.length();
        for (uint256 i = 0; i < count; i++) {
            updatePrice(core.markets[core.marketIDs.at(i)], currentTime);
        }
    }

    function updatePrice(Market storage market, uint256 currentTime) internal {
        // no longer update price after emergency
        if (currentTime != market.priceUpdateTime && market.state == MarketState.NORMAL) {
            updatePriceData(market.markPriceData, IOracle(market.oracle).priceTWAPLong);
            updatePriceData(market.indexPriceData, IOracle(market.oracle).priceTWAPShort);
        }
    }

    function markPrice(Market storage market) internal view returns (int256) {
        return
            market.state == MarketState.NORMAL
                ? market.markPriceData.price
                : market.settlePriceData.price;
    }

    function indexPrice(Market storage market) internal view returns (int256) {
        return
            market.state == MarketState.NORMAL
                ? market.indexPriceData.price
                : market.settlePriceData.price;
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

    function freezeOraclePrice(Market storage market, uint256 currentTime) public {
        require(market.state != MarketState.NORMAL, "market must be in normal state");
        market.settlePriceData = market.indexPriceData;
        market.priceUpdateTime = currentTime;
    }
}
