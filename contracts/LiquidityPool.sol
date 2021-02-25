// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IPoolCreator.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";

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

    /**
     * @dev To receive eth from WETH contract.
     */
    receive() external payable {}

    /**
     * @notice  Initialize the liquidity pool and set up its configuration
     *
     * @param   operator                The address of operator which should be pool creater currently.
     * @param   collateral              The address of collateral token.
     * @param   collateralDecimals      The decimals of collateral token, to support token without decimals interface.
     * @param   governor                The address of governor, who is able to call governance methods.
     * @param   shareToken              The address of share token, which is the token for liquidity providers.
     * @param   isFastCreationEnabled   True if the operator is able to create new perpetual without governor
     *                                  when the liquidity pool is running.
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
            _msgSender(),
            collateral,
            collateralDecimals,
            operator,
            governor,
            shareToken,
            isFastCreationEnabled
        );
    }

    /**
     * @notice  Create new perpetual of the liquidity pool.
     *          The operator can create perpetual only when the pool is not running or isFastCreationEnabled is true.
     *          Otherwise a perpetual can only be create by governor (say, through voting).
     *
     * @param   oracle              The oracle's address of the perpetual.
     * @param   coreParams          The core parameters of the perpetual, see TODO for details.
     * @param   riskParams          The risk parameters of the perpetual,
     *                              Must be within range [minRiskParamValues, maxRiskParamValues].
     * @param   minRiskParamValues  The minimum values of risk parameters.
     * @param   maxRiskParamValues  The maximum values of risk parameters.
     */
    function createPerpetual(
        address oracle,
        int256[11] calldata coreParams,
        int256[6] calldata riskParams,
        int256[6] calldata minRiskParamValues,
        int256[6] calldata maxRiskParamValues
    ) external {
        if (!_liquidityPool.isRunning || _liquidityPool.isFastCreationEnabled) {
            require(
                _msgSender() == _liquidityPool.getOperator(),
                "only operator can create perpetual"
            );
        } else {
            require(_msgSender() == _liquidityPool.governor, "only governor can create perpetual");
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
     * @notice  Set the liquidity pool to running state. Can be call only once by operater.m n
     */
    function runLiquidityPool() external onlyOperator {
        require(!_liquidityPool.isRunning, "already running");
        _liquidityPool.runLiquidityPool();
    }

    /**
     * @notice  If you want to get the real-time data, call this function first
     */
    function forceToSyncState() public syncState(false) {}

    /**
     * @notice  Add liquidity to the liquidity pool.
     *          Liquidity provider deposits collaterals then gets share tokens back.
     *          The ratio of added cash to share token is determined by current liquidity.
     *
     * @param   cashToAdd   The amount of cash to add. always use decimals 18.
     */
    function addLiquidity(int256 cashToAdd) external payable syncState(false) nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        _liquidityPool.addLiquidity(_msgSender(), cashToAdd);
    }

    /**
     * @notice  Remove liquidity from the liquidity pool.
     *          Liquidity providers redeems share token then gets collateral back.
     *          The amount of collateral retrieved may differ from the amount when adding liquidity,
     *          The index price, trading fee and positions holding by amm will affect the profitability of providers.
     *
     * @param   shareToRemove   The amount of share token to remove
     */
    function removeLiquidity(int256 shareToRemove) external syncState(false) nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        require(shareToRemove > 0, "invalid share");
        _liquidityPool.removeLiquidity(_msgSender(), shareToRemove);
    }

    /**
     * @notice  Add liquidity to the liquidity pool without getting shares.
     *
     * @param   cashToAdd   The amount of cash to add. always use decimals 18.
     */
    function donateLiquidity(int256 cashToAdd) external payable nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        _liquidityPool.donateLiquidity(_msgSender(), cashToAdd);
    }

    bytes32[50] private __gap;
}
