// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IFactory.sol";
import "./interface/IOracle.sol";

import "./module/MarketModule.sol";

import "./Events.sol";
import "./Governance.sol";
import "./Trade.sol";
import "./Type.sol";
import "./Settlement.sol";
import "./Storage.sol";

contract Perpetual is Storage, Trade, Settlement, Governance {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using MarketModule for Market;

    function initialize(
        address operator,
        address oracle,
        address governor,
        address shareToken,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external initializer {
        address collateral = IOracle(oracle).collateral();
        Storage.initialize(collateral, operator, governor, shareToken);
        bytes32 marketID = MarketModule.marketID(oracle);
        _core.markets[marketID].initialize(
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    function createMarket(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external onlyOperator {
        require(!_core.isFinalized, "core is finalized");
        bytes32 marketID = MarketModule.marketID(oracle);
        require(!_core.marketIDs.contains(marketID), "market is duplicated");
        _core.markets[marketID].initialize(
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }
}
