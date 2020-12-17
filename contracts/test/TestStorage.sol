// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/CoreModule.sol";
import "../module/PerpetualModule.sol";

import "../Storage.sol";
import "../Getter.sol";

contract TestStorage is Storage, Getter {
    using CoreModule for Core;
    using PerpetualModule for Perpetual;

    function initializeCore(
        address collateral,
        address operator,
        address governor,
        address shareToken
    ) external {
        _core.initialize(collateral, operator, governor, shareToken);
    }

    function initializePerpetual(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 perpetualIndex = _core.perpetuals.length;
        _core.perpetuals.push();
        _core.perpetuals[perpetualIndex].initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        _core.perpetuals[perpetualIndex].state = PerpetualState.NORMAL;
    }
}
