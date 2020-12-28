// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./module/PerpetualModule.sol";

import "./Type.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain liquidityPool parameters.
contract Governance is Storage {
    using SafeMathUpgradeable for uint256;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    address internal _unconfirmedOperator;
    uint256 internal _transferExpiration;

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

    function transferOperatingship(address newOperator, uint256 expiration) external {
        require(
            msg.sender == _liquidityPool.operator || _liquidityPool.operator == address(0),
            "can not transfer now"
        );
        require(newOperator != address(0), "new operator is invalid");
        _unconfirmedOperator = newOperator;
        _transferExpiration = expiration;
    }

    function claimOperatingship() external {
        require(msg.sender == _unconfirmedOperator, "claimer must be specified by operator");
        require(block.timestamp <= _transferExpiration, "transfer is expired");
        _liquidityPool.operator = _unconfirmedOperator;
        _unconfirmedOperator = address(0);
        _transferExpiration = 0;
    }

    function revokeOperatingship() external onlyOperator {
        _liquidityPool.operator = address(0);
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

    function forceToSetEmergencyState(uint256 perpetualIndex)
        external
        onlyGovernor
        onlyExistedPerpetual(perpetualIndex)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.rebalanceFrom(perpetual);
        perpetual.setEmergencyState();
    }

    function setEmergencyState(uint256 perpetualIndex)
        external
        syncState
        onlyExistedPerpetual(perpetualIndex)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.rebalanceFrom(perpetual);
        if (!perpetual.isAMMMarginSafe()) {
            perpetual.setEmergencyState();
        }
    }

    bytes[50] private __gap;
}
