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
     * @notice Initialize liquidity pool 
     * @param operator The address of operator
     * @param collateral The address of collateral
     * @param collateralDecimals The decimal of collateral
     * @param governor The address of governor
     * @param shareToken The address of share token
     * @param isFastCreationEnabled If operator of the liquidity pool is allowed to create new perpetual
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
     * @notice Create perpetual
     * @param oracle The oracle of perpetual
     * @param coreParams The core parameters of perpetual
     * @param riskParams The risk parameters of perpetual
     * @param minRiskParamValues The risk parameters' minimum values of perpetual
     * @param maxRiskParamValues The risk parameters' maximum values of perpetual
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
     * @notice Run liquidity pool. Only operator can run
     */
    function runLiquidityPool() external onlyOperator {
        require(!_liquidityPool.isRunning, "pool is already running");
        _liquidityPool.runLiquidityPool();
    }

    /**
     * @notice Claim fee
     * @param claimer The claimer
     * @param amount The amount to claim
     */
    function claimFee(address claimer, int256 amount) external nonReentrant {
        _liquidityPool.claimFee(claimer, amount);
    }

    /**
     * @notice Add liquidity to liquidity pool
     * @param cashToAdd The amount of collateral to add
     */
    function addLiquidity(int256 cashToAdd) external payable syncState nonReentrant {
        require(cashToAdd > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.addLiquidity(msg.sender, cashToAdd);
    }

    /**
     * @notice Remove liquidity from liquidity pool
     * @param shareToRemove The amount of share token to remove
     */
    function removeLiquidity(int256 shareToRemove) external syncState nonReentrant {
        require(shareToRemove > 0, "invalid share");
        _liquidityPool.removeLiquidity(msg.sender, shareToRemove);
    }

    bytes[50] private __gap;
}
