// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./module/MarketModule.sol";
import "./module/ParameterModule.sol";

import "./Type.sol";
import "./Events.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain perpetual parameters.
contract Governance is Storage, Events {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using MarketModule for Market;
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
    ) external onlyGovernor {
        require(_core.marketIDs.contains(marketID), "market not exist");
        _core.markets[marketID].updateCoreParameter(key, newValue);
        _core.markets[marketID].validateCoreParameters();
        emit UpdateCoreSetting(key, newValue);
    }

    function updateRiskParameter(
        bytes32 marketID,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor {
        require(_core.marketIDs.contains(marketID), "market not exist");
        _core.markets[marketID].updateRiskParameter(key, newValue, minValue, maxValue);
        _core.markets[marketID].validateRiskParameters();
        emit UpdateRiskSetting(key, newValue, minValue, maxValue);
    }

    function adjustRiskParameter(
        bytes32 marketID,
        bytes32 key,
        int256 newValue
    ) external onlyOperator {
        require(_core.marketIDs.contains(marketID), "market not exist");
        _core.markets[marketID].adjustRiskParameter(key, newValue);
        _core.markets[marketID].validateRiskParameters();
        emit AdjustRiskSetting(key, newValue);
    }
}
