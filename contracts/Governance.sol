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

    /**
     * @notice Transfer operator of liquidity pool.
     *         Only operator can transfer if operator exists.
     *         Only governor can transfer if operator doesn't exist
     * @param newOperator The new operator
     */
    function transferOperator(address newOperator) external {
        if (_liquidityPool.operator != address(0)) {
            require(msg.sender == _liquidityPool.operator, "can only be initiated by operator");
        } else {
            require(msg.sender == _liquidityPool.governor, "can only be initiated by governor");
        }
        _liquidityPool.transferOperator(newOperator);
    }

    /**
     * @notice Claim operator of liquidity pool.
     */
    function claimOperator() external {
        address previousOperator = _liquidityPool.operator;
        _liquidityPool.claimOperator(msg.sender);
        _liquidityPool.claimFee(previousOperator, _liquidityPool.claimableFees[previousOperator]);
    }

    /**
     * @notice Revoke operator of liquidity pool.
     *         Only operator can revoke
     */
    function revokeOperator() external onlyOperator {
        _liquidityPool.revokeOperator();
    }

    /**
     * @notice Claim fee of operator. Only operator can claim
     */
    function claimOperatorFee() external onlyOperator {
        address operator = _liquidityPool.operator;
        _liquidityPool.claimFee(operator, _liquidityPool.claimableFees[operator]);
    }

    /**
     * @notice Set parameter of liquidity pool.
     *         Only governor can set
     * @param key The key of parameter
     * @param newValue The new value of parameter
     */
    function setLiquidityPoolParameter(bytes32 key, int256 newValue) external onlyGovernor {
        _liquidityPool.setLiquidityPoolParameter(key, newValue);
    }

    /**
     * @notice Set base parameter of perpetual.
     *         Only governor can set
     * @param perpetualIndex The index of perpetual
     * @param key The key of base parameter
     * @param newValue The new value of base parameter
     */
    function setPerpetualBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor {
        _liquidityPool.setPerpetualBaseParameter(perpetualIndex, key, newValue);
    }

    /**
     * @notice Set risk parameter of perpetual.
     *         Only governor can set
     * @param perpetualIndex The index of perpetual
     * @param key The key of risk parameter
     * @param newValue The new value of risk parameter
     * @param minValue The minimum value of risk parameter
     * @param maxValue The maximum value of risk parameter
     */
    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external onlyGovernor {
        _liquidityPool.setPerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    /**
     * @notice Update risk parameter of perpetual.
     *         Only operator can update
     * @param perpetualIndex The index of perpetual
     * @param key The key of risk parameter
     * @param newValue The new value of risk parameter
     */
    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator {
        _liquidityPool.updatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    /**
     * @notice Force to set state of perpetual to emergency.
     *         Only governor can set
     * @param perpetualIndex The index of perpetual
     */
    function forceToSetEmergencyState(uint256 perpetualIndex) external syncState onlyGovernor {
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    /**
     * @notice Set state of perpetual to emergency if amm isn't maintenance margin safe
     * @param perpetualIndex The index of perpetual
     */
    function setEmergencyState(uint256 perpetualIndex) external syncState {
        require(!_liquidityPool.isAMMMaintenanceMarginSafe(perpetualIndex), "amm is safe");
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    bytes[50] private __gap;
}
