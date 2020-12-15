// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./module/MarketModule.sol";
import "./module/ParameterModule.sol";

import "./Type.sol";
import "./Events.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain liquidityPool parameters.
contract Governance is Storage, Events {
    using SafeMathUpgradeable for uint256;
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

    function updateMarketParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor onlyExistedMarket(marketIndex) {
        _core.markets[marketIndex].updateMarketParameter(key, newValue);
        _core.markets[marketIndex].validateCoreParameters();
        emit UpdateMarketParameter(marketIndex, key, newValue);
    }

    function updateMarketRiskParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor onlyExistedMarket(marketIndex) {
        _core.markets[marketIndex].updateMarketRiskParameter(key, newValue, minValue, maxValue);
        _core.markets[marketIndex].validateRiskParameters();
        emit UpdateMarketRiskParameter(marketIndex, key, newValue, minValue, maxValue);
    }

    function adjustMarketRiskParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator onlyExistedMarket(marketIndex) {
        _core.markets[marketIndex].adjustMarketRiskParameter(key, newValue);
        _core.markets[marketIndex].validateRiskParameters();
        emit AdjustMarketRiskSetting(marketIndex, key, newValue);
    }

    bytes[50] private __gap;
}
