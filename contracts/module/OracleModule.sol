// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Type.sol";
import "../interface/IOracle.sol";
import "./StateModule.sol";

library OracleModule {
    using StateModule for Core;

    function markPrice(Core storage core) internal view returns (int256) {
        return core.isNormal() ? core.markPriceData.price : core.settlePriceData.price;
    }

    function updatePrice(Core storage core) internal {
        if (block.timestamp != core.priceUpdateTime) {
            updatePriceData(core.markPriceData, IOracle(core.oracle).priceTWAPLong);
            updatePriceData(core.indexPriceData, IOracle(core.oracle).priceTWAPShort);
            core.priceUpdateTime = block.timestamp;
        }
    }

    function indexPrice(Core storage core) internal view returns (int256) {
        return core.isNormal() ? core.indexPriceData.price : core.settlePriceData.price;
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
}
