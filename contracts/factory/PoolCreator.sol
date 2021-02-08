// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "../thirdparty/proxy/UpgradeableProxy.sol";
import "../thirdparty/cloneFactory/CloneFactory.sol";

import "../interface/IGovernor.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IShareToken.sol";

import "./Tracer.sol";
import "./Implementation.sol";
import "./Variables.sol";
import "./AccessControl.sol";

contract PoolCreator is Tracer, Implementation, Variables, AccessControl, CloneFactory {
    using Address for address;

    address internal _governorTemplate;
    address internal _shareTokenTemplate;

    constructor(
        address governorTemplate,
        address shareTokenTemplate,
        address wethToken,
        address symbolService,
        address globalVault,
        int256 globalVaultFeeRate
    ) Variables(wethToken, symbolService, globalVault, globalVaultFeeRate) Implementation() {
        require(governorTemplate.isContract(), "governor template must be contract");
        require(shareTokenTemplate.isContract(), "share token template must be contract");
        _governorTemplate = governorTemplate;
        _shareTokenTemplate = shareTokenTemplate;
    }

    event CreateLiquidityPool(
        address liquidityPool,
        address governor,
        address shareToken,
        address operator,
        address collateral,
        uint256 collateralDecimals,
        bool isFastCreationEnabled
    );

    /**
     * @notice Create a liquidity pool with the latest implementation. The operator is sender
     * @param collateral The collateral address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param isFastCreationEnabled If the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     * @param nonce The nonce for the creation
     * @return address The address of the created liquidity pool
     */
    function createLiquidityPool(
        address collateral,
        uint256 collateralDecimals,
        bool isFastCreationEnabled,
        int256 nonce
    ) external returns (address) {
        return
            _createLiquidityPoolWith(
                getLatestVersion(),
                collateral,
                collateralDecimals,
                isFastCreationEnabled,
                nonce
            );
    }

    /**
     * @notice Create a liquidity pool with the specific implementation. The operator is sender
     * @param implementation The address of the implementation
     * @param collateral The collateral address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param isFastCreationEnabled If the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     * @param nonce The nonce for the creation
     * @return address The address of the created liquidity pool
     */
    function createLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 collateralDecimals,
        bool isFastCreationEnabled,
        int256 nonce
    ) external returns (address) {
        return
            _createLiquidityPoolWith(
                implementation,
                collateral,
                collateralDecimals,
                isFastCreationEnabled,
                nonce
            );
    }

    /**
     * @dev Create a liquidity pool with the specific implementation. The operator is sender
     * @param implementation The address of implementation
     * @param collateral The collateral address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param isFastCreationEnabled If the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     * @param nonce The nonce for the creation
     * @return address The address of the created liquidity pool
     */
    function _createLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 collateralDecimals,
        bool isFastCreationEnabled,
        int256 nonce
    ) internal returns (address) {
        require(isVersionValid(implementation), "invalid implementation");
        address governor = _createClone(_shareTokenTemplate);
        address shareToken = governor;
        bytes32 argsHash =
            keccak256(abi.encode(collateral, collateralDecimals, isFastCreationEnabled));
        address liquidityPool = _createUpgradeableProxy(implementation, governor, argsHash, nonce);
        // initialize
        address operator = msg.sender;
        IShareToken(governor).initialize(
            "MCDEX Share Token",
            "STK",
            liquidityPool,
            liquidityPool,
            getMCBToken(),
            getVault()
        );
        // IGovernor(governor).initialize(shareToken, liquidityPool);
        ILiquidityPool(liquidityPool).initialize(
            operator,
            collateral,
            collateralDecimals,
            governor,
            shareToken,
            isFastCreationEnabled
        );
        // register
        _registerLiquidityPool(liquidityPool, operator);
        emit CreateLiquidityPool(
            liquidityPool,
            governor,
            shareToken,
            operator,
            collateral,
            collateralDecimals,
            isFastCreationEnabled
        );
        return liquidityPool;
    }

    /**
     * @dev Create a clone contract of the implementation of liquidity pool
     * @param implementation The address of the implementation
     * @return address The address of the cloned contract
     */
    function _createClone(address implementation) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        return createClone(implementation);
    }

    /**
     * @dev Create an upgradeable proxy contract of the implementation of liquidity pool
     * @param implementation The address of the implementation
     * @param admin The admin address of the created contract
     * @param argsHash The hash of the arguments for the creation
     * @param nonce The nonce for the creation
     * @return instance The address of the created upgradeable proxy contract
     */
    function _createUpgradeableProxy(
        address implementation,
        address admin,
        bytes32 argsHash,
        int256 nonce
    ) internal returns (address instance) {
        require(implementation != address(0), "invalid implementation");
        require(Address.isContract(implementation), "implementation must be contract");
        bytes memory deploymentData =
            abi.encodePacked(
                type(UpgradeableProxy).creationCode,
                abi.encode(implementation, admin)
            );
        bytes32 salt = keccak256(abi.encode(implementation, admin, msg.sender, argsHash, nonce));
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "create2 call failed");
    }
}
