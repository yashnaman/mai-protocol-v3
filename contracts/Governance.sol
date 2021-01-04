// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./module/PerpetualModule.sol";
import "./module/SignatureModule.sol";

import "./Type.sol";
import "./Storage.sol";

// @title Goovernance is the contract to maintain liquidityPool parameters.
contract Governance is Storage {
    using SafeMathUpgradeable for uint256;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using SignatureModule for bytes32;

    address internal _unconfirmedOperator;
    uint256 internal _transferExpiration;

    modifier onlyGovernor() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _liquidityPool.operator, "only operator is allowed");
        _;
    }

    function transferOperator(address newOperator) external {
        if (_liquidityPool.operator != address(0)) {
            require(msg.sender == _liquidityPool.operator, "can only be initiated by operator");
        } else {
            require(msg.sender == _liquidityPool.governor, "can only be initiated by governor");
        }
        _liquidityPool.transferOperator(newOperator);
    }

    function claimOperatingship() external {
        _liquidityPool.claimOperator(msg.sender);
    }

    function revokeOperator() external onlyOperator {
        require(msg.sender == _liquidityPool.operator, "can only be initiated by operator");
        _liquidityPool.revokeOperator();
    }

    function setLiquidityPoolParameter(bytes32 key, int256 newValue) external onlyGovernor {
        _liquidityPool.setLiquidityPoolParameter(key, newValue);
    }

    function setPerpetualBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor {
        _liquidityPool.setPerpetualBaseParameter(perpetualIndex, key, newValue);
    }

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor {
        _liquidityPool.setPerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator {
        _liquidityPool.updatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    function forceToSetEmergencyState(uint256 perpetualIndex) external syncState onlyGovernor {
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    function setEmergencyState(uint256 perpetualIndex) external syncState {
        require(!_liquidityPool.isAMMMarginSafe(perpetualIndex), "amm is safe");
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    bytes[50] private __gap;
}
