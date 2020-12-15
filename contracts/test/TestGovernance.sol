// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarketModule.sol";

import "../Governance.sol";

contract TestGovernance is Governance {
    using MarketModule for Market;

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
        _core.markets.push();
        _core.markets[0].initialize(
            0,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    function initialMarginRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].initialMarginRate;
    }

    function maintenanceMarginRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].maintenanceMarginRate;
    }

    function operatorFeeRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].operatorFeeRate;
    }

    function lpFeeRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].lpFeeRate;
    }

    function referrerRebateRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].referrerRebateRate;
    }

    function liquidationPenaltyRate(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].liquidationPenaltyRate;
    }

    function keeperGasReward(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].keeperGasReward;
    }

    function halfSpread(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].halfSpread.value;
    }

    function openSlippageFactor(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].openSlippageFactor.value;
    }

    function closeSlippageFactor(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].closeSlippageFactor.value;
    }

    function fundingRateCoefficient(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].fundingRateCoefficient.value;
    }

    function maxLeverage(uint256 marketIndex) public view returns (int256) {
        return _core.markets[marketIndex].maxLeverage.value;
    }
}
