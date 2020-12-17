// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../interface/IOracle.sol";

import "../Type.sol";

library OracleModule {
    function updatePrice(Core storage core, uint256 currentTime) internal {
        if (core.priceUpdateTime >= currentTime) {
            return;
        }
        uint256 length = core.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updatePrice(core.perpetuals[i]);
        }
        core.priceUpdateTime = currentTime;
    }

    function updatePrice(Perpetual storage perpetual) internal {
        // no longer update price after emergency
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        updatePriceData(perpetual.markPriceData, IOracle(perpetual.oracle).priceTWAPLong);
        updatePriceData(perpetual.indexPriceData, IOracle(perpetual.oracle).priceTWAPShort);
    }

    function markPrice(Perpetual storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.markPriceData.price
                : perpetual.settlementPriceData.price;
    }

    function indexPrice(Perpetual storage perpetual) internal view returns (int256) {
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

    function freezeOraclePrice(Perpetual storage perpetual) public {
        perpetual.settlementPriceData = perpetual.indexPriceData;
    }
}
