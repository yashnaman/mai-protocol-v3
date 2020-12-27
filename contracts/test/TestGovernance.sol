// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/PerpetualModule.sol";

import "../Governance.sol";

contract TestGovernance is Governance {
    using PerpetualModule for PerpetualStorage;

    function setGovernor(address governor) public {
        _governor = governor;
    }

    function setOperator(address operator) public {
        _liquidityPool.operator = operator;
    }

    function initializeParameters(
        address oracle,
        int256[9] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) public {
        _liquidityPool.perpetuals.push();
        _liquidityPool.perpetuals[0].initialize(
            0,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    function settlementPrice(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.settlementPriceData.price;
    }

    function setOracle(uint256 perpetualIndex, address oracle) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.oracle = oracle;
    }

    function isFastCreationEnabled() public view returns (bool) {
        return _liquidityPool.isFastCreationEnabled;
    }

    function initialMarginRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].initialMarginRate;
    }

    function maintenanceMarginRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].maintenanceMarginRate;
    }

    function operatorFeeRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].operatorFeeRate;
    }

    function lpFeeRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].lpFeeRate;
    }

    function referrerRebateRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].referrerRebateRate;
    }

    function liquidationPenaltyRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].liquidationPenaltyRate;
    }

    function keeperGasReward(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].keeperGasReward;
    }

    function halfSpread(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].halfSpread.value;
    }

    function openSlippageFactor(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].openSlippageFactor.value;
    }

    function closeSlippageFactor(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].closeSlippageFactor.value;
    }

    function fundingRateLimit(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].fundingRateLimit.value;
    }

    function ammMaxLeverage(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].ammMaxLeverage.value;
    }

    function state(uint256 perpetualIndex) public view returns (PerpetualState) {
        return _liquidityPool.perpetuals[perpetualIndex].state;
    }

    function setState(uint256 perpetualIndex, PerpetualState state) public {
        _liquidityPool.perpetuals[perpetualIndex].state = state;
    }
}
