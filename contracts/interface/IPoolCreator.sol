// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

import "./IProxyAdmin.sol";

interface IPoolCreator {
    function upgradeAdmin() external view returns (IProxyAdmin proxyAdmin);

    /**
     * @notice  Create a liquidity pool with the latest version.
     *          The sender will be the operator of pool.
     *
     * @param   collateral              he collateral address of the liquidity pool.
     * @param   collateralDecimals      The collateral's decimals of the liquidity pool.
     * @param   nonce                   A random nonce to calculate the address of deployed contracts.
     * @param   initData                A bytes array contains data to initialize new created liquidity pool.
     * @return  liquidityPool           The address of the created liquidity pool.
     */
    function createLiquidityPool(
        address collateral,
        uint256 collateralDecimals,
        int256 nonce,
        bytes calldata initData
    ) external returns (address liquidityPool, address governor);

    /**
     * @notice  Create a liquidity pool with the specific version. The operator will be the sender.
     *
     * @param   versionKey          The key of the version to create.
     * @param   collateral          The collateral address of the liquidity pool.
     * @param   collateralDecimals  The collateral's decimals of the liquidity pool.
     * @param   nonce               A random nonce to calculate the address of deployed contracts.
     * @param   initData            A bytes array contains data to initialize new created liquidity pool.
     * @return  liquidityPool       The address of the created liquidity pool.
     * @return  governor            The address of the created governor.
     */
    function createLiquidityPoolWith(
        bytes32 versionKey,
        address collateral,
        uint256 collateralDecimals,
        int256 nonce,
        bytes memory initData
    ) external returns (address liquidityPool, address governor);

    /**
     * @notice  Upgrade a liquidity pool and governor pair then call a patch function on the upgraded contract (optional).
     *          This method checks the sender and forwards the request to ProxyAdmin to do upgrading.
     *
     * @param   targetVersionKey        The key of version to be upgrade up. The target version must be compatible with
     *                                  current version.
     * @param   dataForLiquidityPool    The patch calldata for upgraded liquidity pool.
     * @param   dataForGovernor         The patch calldata of upgraded governor.
     */
    function upgradeToAndCall(
        bytes32 targetVersionKey,
        bytes memory dataForLiquidityPool,
        bytes memory dataForGovernor
    ) external;
}
