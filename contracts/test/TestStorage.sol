// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/CoreModule.sol";
import "../module/MarketModule.sol";

import "../Storage.sol";
import "../Getter.sol";

contract TestStorage is Storage, Getter {
    using CoreModule for Core;
    using MarketModule for Market;

    function initializeCore(
        address collateral,
        address operator,
        address governor,
        address shareToken
    ) external {
        _core.initialize(collateral, operator, governor, shareToken);
    }

    function initializeMarket(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 marketIndex = _core.markets.length;
        _core.markets.push();
        _core.markets[marketIndex].initialize(
            marketIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        _core.markets[marketIndex].state = MarketState.NORMAL;
    }
}
