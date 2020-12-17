// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./module/PerpetualModule.sol";
import "./module/ParameterModule.sol";

import "./Type.sol";
import "./Events.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain liquidityPool parameters.
contract Governance is Storage, Events {
    using SafeMathUpgradeable for uint256;
    using PerpetualModule for Perpetual;
    using ParameterModule for Perpetual;
    using ParameterModule for Core;

    uint256 internal constant INDEX_PRICE_TIMEOUT = 24 * 3600;

    modifier onlyGovernor() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _core.operator, "only operator is allowed");
        _;
    }

    function updateLiquidityPoolParameter(bytes32 key, int256 newValue) external onlyGovernor {
        _core.updateLiquidityPoolParameter(key, newValue);
        emit UpdateLiquidityPoolParameter(key, newValue);
    }

    function updatePerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        _core.perpetuals[perpetualIndex].updatePerpetualParameter(key, newValue);
        _core.perpetuals[perpetualIndex].validateCoreParameters();
        emit UpdatePerpetualParameter(perpetualIndex, key, newValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        _core.perpetuals[perpetualIndex].updatePerpetualRiskParameter(
            key,
            newValue,
            minValue,
            maxValue
        );
        _core.perpetuals[perpetualIndex].validateRiskParameters();
        emit UpdatePerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    function adjustPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator onlyExistedPerpetual(perpetualIndex) {
        _core.perpetuals[perpetualIndex].adjustPerpetualRiskParameter(key, newValue);
        _core.perpetuals[perpetualIndex].validateRiskParameters();
        emit AdjustPerpetualRiskSetting(perpetualIndex, key, newValue);
    }

    bytes[50] private __gap;
}
