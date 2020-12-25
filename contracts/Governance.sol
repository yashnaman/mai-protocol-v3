// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./module/PerpetualModule.sol";

import "./Type.sol";
import "./Events.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain liquidityPool parameters.
contract Governance is Storage {
    using SafeMathUpgradeable for uint256;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    event SetLiquidityPoolParameter(bytes32 key, int256 value);
    event SetPerpetualParameter(uint256 perpetualIndex, bytes32 key, int256 value);
    event SetPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 value,
        int256 minValue,
        int256 maxValue
    );
    event UpdatePerpetualRiskParameter(uint256 perpetualIndex, bytes32 key, int256 value);

    modifier onlyGovernor() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _liquidityPool.operator, "only operator is allowed");
        _;
    }

    function setLiquidityPoolParameter(bytes32 key, int256 newValue) external onlyGovernor {
        _liquidityPool.setParameter(key, newValue);
        emit SetLiquidityPoolParameter(key, newValue);
    }

    function setPerpetualBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.setBaseParameter(key, newValue);
        perpetual.validateBaseParameters();
        emit SetPerpetualParameter(perpetualIndex, key, newValue);
    }

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.setRiskParameter(key, newValue, minValue, maxValue);
        perpetual.validateRiskParameters();
        emit SetPerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator onlyExistedPerpetual(perpetualIndex) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateRiskParameter(key, newValue);
        perpetual.validateRiskParameters();
        emit UpdatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    function forceToEnterEmergencyState(uint256 perpetualIndex)
        external
        onlyGovernor
        onlyExistedPerpetual(perpetualIndex)
    {
        _liquidityPool.perpetuals[perpetualIndex].enterEmergencyState();
    }

    function enterEmergencyState(uint256 perpetualIndex)
        external
        onlyExistedPerpetual(perpetualIndex)
    {
        // require(amm unsafe)
        _liquidityPool.perpetuals[perpetualIndex].enterEmergencyState();
    }

    bytes[50] private __gap;
}
