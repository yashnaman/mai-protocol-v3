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
    using PerpetualModule for PerpetualStorage;
    using ParameterModule for PerpetualStorage;
    using ParameterModule for LiquidityPoolStorage;

    uint256 internal constant INDEX_PRICE_TIMEOUT = 24 * 3600;

    modifier onlyGovernor() {
        require(msg.sender == _governor, "only governor is allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _liquidityPool.operator, "only operator is allowed");
        _;
    }

    function setPerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        _liquidityPool.perpetuals[perpetualIndex].setPerpetualParameter(key, newValue);
        _liquidityPool.perpetuals[perpetualIndex].validateCoreParameters();
        emit SetPerpetualParameter(perpetualIndex, key, newValue);
    }

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor onlyExistedPerpetual(perpetualIndex) {
        _liquidityPool.perpetuals[perpetualIndex].setPerpetualRiskParameter(
            key,
            newValue,
            minValue,
            maxValue
        );
        _liquidityPool.perpetuals[perpetualIndex].validateRiskParameters();
        emit SetPerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator onlyExistedPerpetual(perpetualIndex) {
        _liquidityPool.perpetuals[perpetualIndex].updatePerpetualRiskParameter(key, newValue);
        _liquidityPool.perpetuals[perpetualIndex].validateRiskParameters();
        emit UpdatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    bytes[50] private __gap;
}
