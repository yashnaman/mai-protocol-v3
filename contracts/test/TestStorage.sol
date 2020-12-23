// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/LiquidityPoolModule.sol";
import "../module/PerpetualModule.sol";

import "../Storage.sol";
import "../Getter.sol";

contract TestStorage is Storage, Getter {
    using LiquidityPoolModule for LiquidityPoolStorage;
    using PerpetualModule for PerpetualStorage;

    function initializeCore(
        address collateral,
        address operator,
        address governor,
        address shareToken,
        int256 insuranceFundCap
    ) external {
        _liquidityPool.initialize(collateral, operator, governor, shareToken, insuranceFundCap);
    }

    function initializePerpetual(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 perpetualIndex = _liquidityPool.perpetuals.length;
        _liquidityPool.perpetuals.push();
        _liquidityPool.perpetuals[perpetualIndex].initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        _liquidityPool.perpetuals[perpetualIndex].state = PerpetualState.NORMAL;
    }
}
