// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./module/ParameterModule.sol";

import "./Type.sol";
import "./Events.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain perpetual parameters.
contract Governance is Storage, Events {
    using SafeMath for uint256;
    using ParameterModule for Market;

    uint256 internal constant INDEX_PRICE_TIMEOUT = 24 * 3600;

    modifier onlyGovernor() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _core.operator, "only operator is allowed");
        _;
    }

    function updateCoreParameter(
        bytes32 marketID,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor onlyValidMarket(marketID) {
        _core.markets[_core.marketIndex[marketID]].updateCoreParameter(key, newValue);
        _core.markets[_core.marketIndex[marketID]].validateCoreParameters();
        emit UpdateCoreSetting(key, newValue);
    }

    function updateRiskParameter(
        bytes32 marketID,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor onlyValidMarket(marketID) {
        _core.markets[_core.marketIndex[marketID]].updateRiskParameter(
            key,
            newValue,
            minValue,
            maxValue
        );
        _core.markets[_core.marketIndex[marketID]].validateRiskParameters();
        emit UpdateRiskSetting(key, newValue, minValue, maxValue);
    }

    function adjustRiskParameter(
        bytes32 marketID,
        bytes32 key,
        int256 newValue
    ) external onlyOperator onlyValidMarket(marketID) {
        _core.markets[_core.marketIndex[marketID]].adjustRiskParameter(key, newValue);
        _core.markets[_core.marketIndex[marketID]].validateRiskParameters();
        emit AdjustRiskSetting(key, newValue);
    }
}
