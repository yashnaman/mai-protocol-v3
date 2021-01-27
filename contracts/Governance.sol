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

    function setOperator(address newOperator) external onlyGovernor {
        require(_liquidityPool.operator == address(0), "can only be called when no operator");
        _liquidityPool.transferOperator(newOperator);
    }

    /**
     * @notice Transfer the ownership of the liquidity pool to the new operator, call claimOperator()
     *         next to complete the transfer
     *         Can only called by the operator if the operator exists.
     *         Can only called by the governor if the operator doesn't exist
     * @param newOperator The address of the new operator
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
     * @notice Claim the ownership of the liquidity pool to sender.
     *         Sender must be transferred the ownership before.
     *         Will claim all the claimable fee of previous operator
     */
    function claimOperator() external {
        address previousOperator = _liquidityPool.operator;
        _liquidityPool.claimOperator(msg.sender);
        // if (_liquidityPool.claimableFees[previousOperator] > 0) {
        //     _liquidityPool.claimFee(
        //         previousOperator,
        //         _liquidityPool.claimableFees[previousOperator]
        //     );
        // }
    }

    /**
     * @notice Revoke the operator of the liquidity pool. Can only called by the operator
     */
    function revokeOperator() external onlyOperator {
        _liquidityPool.revokeOperator();
    }

    // /**
    //  * @notice Claim the claimable fee of the operator. Can only called by the operator
    //  */
    // function claimOperatorFee() external onlyOperator {
    //     address operator = _liquidityPool.operator;
    //     _liquidityPool.claimFee(operator, _liquidityPool.claimableFees[operator]);
    // }

    /**
     * @notice Set the parameter of the liquidity pool. Can only called by the governor
     * @param key The key of the parameter
     * @param newValue The new value of the parameter
     */
    function setLiquidityPoolParameter(bytes32 key, int256 newValue) external onlyGovernor {
        _liquidityPool.setLiquidityPoolParameter(key, newValue);
    }

    /**
     * @notice Set the base parameter of the perpetual. Can only called by the governor
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param key The key of the base parameter
     * @param newValue The new value of the base parameter
     */
    function setPerpetualBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyGovernor {
        _liquidityPool.setPerpetualBaseParameter(perpetualIndex, key, newValue);
    }

    /**
     * @notice Set the risk parameter of the perpetual, including minimum value and maximum value. Can only called by the governor
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param key The key of the risk parameter
     * @param newValue The new value of the risk parameter, must between minimum value and maximum value
     * @param minValue The minimum value of the risk parameter
     * @param maxValue The maximum value of the risk parameter
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
     * @notice Update the risk parameter of the perpetual. Can only called by the operator
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param key The key of the risk parameter
     * @param newValue The new value of the risk parameter, must between minimum value and maximum value
     */
    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external onlyOperator {
        _liquidityPool.updatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    /**
     * @notice Force tp set the state of the perpetual to "EMERGENCY".
     *         Can only called by the governor.
     *         Must rebalance first. After that the perpetual is not allowed to trade, deposit and withdraw.
     *         The price of the perpetual is freezed to the settlement price.
     *         Need to update the funding state and the oracle price of each perpetual before
     *         and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function forceToSetEmergencyState(uint256 perpetualIndex, int256 settlementPrice)
        external
        syncState
        onlyGovernor
    {
        _liquidityPool.setEmergencyState(perpetualIndex, settlementPrice);
    }

    /**
     * @notice Set the state of the perpetual to "EMERGENCY". Must rebalance first.
     *         Can only called when AMM is not maintenance margin safe in the perpetual.
     *         After that the perpetual is not allowed to trade, deposit and withdraw.
     *         The price of the perpetual is freezed to the settlement price.
     *         Need to update the funding state and the oracle price of each perpetual before
     *         and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function setEmergencyState(uint256 perpetualIndex) external syncState {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        require(
            IOracle(perpetual.oracle).isTerminated() ||
                !_liquidityPool.isAMMMaintenanceMarginSafe(perpetualIndex),
            "prerequisite not met"
        );
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    bytes[50] private __gap;
}
