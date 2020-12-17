// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/PerpetualModule.sol";

import "../Governance.sol";

contract TestGovernance is Governance {
    using PerpetualModule for Perpetual;

    function setGovernor(address governor) public {
        _governor = governor;
    }

    function setOperator(address operator) public {
        _core.operator = operator;
    }

    function initializeParameters(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) public {
        _core.perpetuals.push();
        _core.perpetuals[0].initialize(
            0,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    function initialMarginRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].initialMarginRate;
    }

    function maintenanceMarginRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].maintenanceMarginRate;
    }

    function operatorFeeRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].operatorFeeRate;
    }

    function lpFeeRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].lpFeeRate;
    }

    function referrerRebateRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].referrerRebateRate;
    }

    function liquidationPenaltyRate(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].liquidationPenaltyRate;
    }

    function keeperGasReward(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].keeperGasReward;
    }

    function halfSpread(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].halfSpread.value;
    }

    function openSlippageFactor(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].openSlippageFactor.value;
    }

    function closeSlippageFactor(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].closeSlippageFactor.value;
    }

    function fundingRateLimit(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].fundingRateLimit.value;
    }

    function maxLeverage(uint256 perpetualIndex) public view returns (int256) {
        return _core.perpetuals[perpetualIndex].maxLeverage.value;
    }
}
