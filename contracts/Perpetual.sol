// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./interface/IFactory.sol";
import "./interface/IOracle.sol";

import "./Type.sol";
import "./Storage.sol";

import "./Events.sol";
import "./Governance.sol";
import "./Trade.sol";
import "./Settlement.sol";

contract Perpetual is Storage, Trade, Settlement, Governance {
    function initialize(
        address operator,
        address oracle,
        address governor,
        address shareToken,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        _initialize(
            operator,
            oracle,
            governor,
            shareToken,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }
}
