// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IPoolCreator.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";
import "./module/SignatureModule.sol";

import "./Getter.sol";
import "./Governance.sol";
import "./LibraryEvents.sol";
import "./Perpetual.sol";
import "./Storage.sol";
import "./Type.sol";

contract LiquidityPool is Storage, Perpetual, Getter, Governance, LibraryEvents {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using AMMModule for LiquidityPoolStorage;
    using SignatureModule for bytes32;

    receive() external payable {}

    /**
     * @notice Initialize the liquidity pool
     * @param operator The operator's address of the liquidity pool
     * @param collateral The collateral's address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param governor The governor's address of the liquidity pool
     * @param shareToken The share token's address of the liquidity pool
     * @param isFastCreationEnabled If the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     */
    function initialize(
        address operator,
        address collateral,
        uint256 collateralDecimals,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) external initializer {
        _liquidityPool.initialize(
            collateral,
            collateralDecimals,
            operator,
            governor,
            shareToken,
            isFastCreationEnabled
        );
    }

    /**
     * @notice Create new perpetual of the liquidity pool. The operator can create only when the liquidity
     *         pool is not running or isFastCreationEnabled is set to true. In other cases, only the
     *         governor can create
     * @param oracle The oracle's address of the perpetual
     * @param coreParams The core parameters of the perpetual
     * @param riskParams The risk parameters of the perpetual, must between minimum values and maximum values
     * @param minRiskParamValues The risk parameters' minimum values of the perpetual
     * @param maxRiskParamValues The risk parameters' maximum values of the perpetual
     */
    function createPerpetual(
        address oracle,
        int256[9] calldata coreParams,
        int256[6] calldata riskParams,
        int256[6] calldata minRiskParamValues,
        int256[6] calldata maxRiskParamValues
    ) external {
        if (!_liquidityPool.isRunning || _liquidityPool.isFastCreationEnabled) {
            require(msg.sender == _liquidityPool.operator, "only operator can create perpetual");
        } else {
            require(msg.sender == _liquidityPool.governor, "only governor can create perpetual");
        }
        _liquidityPool.createPerpetual(
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    /**
     * @notice Run the liquidity pool. Only operator can run
     */
    function runLiquidityPool() external onlyOperator {
        require(!_liquidityPool.isRunning, "pool is already running");
        _liquidityPool.runLiquidityPool();
    }

    /**
     * @notice Claim fee(collateral) to the claimer
     * @param claimer The address of the claimer
     * @param amount The amount of fee(collateral) to claim
     */
    function claimFee(address claimer, int256 amount) external nonReentrant {
        _liquidityPool.claimFee(claimer, amount);
    }

    /**
     * @notice Add liquidity to the liquidity pool. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param cashToAdd The amount of cash(collateral) to add
     */
    function addLiquidity(int256 cashToAdd) external payable syncState nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        require(cashToAdd > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.addLiquidity(msg.sender, cashToAdd);
    }

    /**
     * @notice Remove liquidity from the liquidity pool. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param shareToRemove The amount of share token to remove
     */
    function removeLiquidity(int256 shareToRemove) external syncState nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        require(shareToRemove > 0, "invalid share");
        _liquidityPool.removeLiquidity(msg.sender, shareToRemove);
    }

    bytes[50] private __gap;
}
