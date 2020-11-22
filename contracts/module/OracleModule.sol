// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Type.sol";
import "../interface/IOracle.sol";
import "./StateModule.sol";

library OracleModule {
    using StateModule for Core;

    function markPrice(Core storage core) internal view returns (int256) {
        return
            core.isNormal()
                ? core.marketPriceData.price
                : core.settlePriceData.price;
    }

    function updateMarkPrice(Core storage core) internal {
        if (block.timestamp != core.marketPriceData.updateTime) {
            (int256 price, uint256 priceTime) = IOracle(core.oracle)
                .priceTWAPLong();
            _updatePrice(core.marketPriceData, price, priceTime);
        }
    }

    function indexPrice(Core storage core) internal view returns (int256) {
        return
            core.isNormal()
                ? core.indexPriceData.price
                : core.settlePriceData.price;
    }

    function updateIndexPrice(Core storage core) internal {
        if (block.timestamp != core.indexPriceData.updateTime) {
            (int256 price, uint256 priceTime) = IOracle(core.oracle)
                .priceTWAPShort();
            _updatePrice(core.indexPriceData, price, priceTime);
        }
    }

    function _updatePrice(
        OraclePriceData storage priceData,
        int256 newPrice,
        uint256 newPriceTime
    ) private {
        if (newPriceTime != priceData.priceTime) {
            priceData.price = newPrice;
            priceData.priceTime = newPriceTime;
            priceData.updateTime = block.timestamp;
        }
    }
}
