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
    using ParameterModule for Core;

    uint256 internal constant INDEX_PRICE_TIMEOUT = 24 * 3600;

    modifier governorOnly() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier operatorOnly() {
        require(msg.sender == _core.operator, "only operator is allowed");
        _;
    }

    function updateCoreParameter(bytes32 key, int256 newValue) external governorOnly {
        _core.updateCoreParameter(key, newValue);
        _core.validateCoreParameters();
        emit UpdateCoreSetting(key, newValue);
    }

    function updateRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external governorOnly {
        _core.updateRiskParameter(key, newValue, minValue, maxValue);
        _core.validateRiskParameters();
        emit UpdateRiskSetting(key, newValue, minValue, maxValue);
    }

    function adjustRiskParameter(bytes32 key, int256 newValue) external operatorOnly {
        _core.adjustRiskParameter(key, newValue);
        _core.validateRiskParameters();
        emit AdjustRiskSetting(key, newValue);
    }
}
