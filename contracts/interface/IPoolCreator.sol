// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IPoolCreator {
    function vault() external view returns (address);

    function vaultFeeRate() external view returns (int256);

    function activatePerpetualFor(address trader, uint256 perpetualIndex) external;

    function deactivatePerpetualFor(address trader, uint256 perpetualIndex) external;

    function setLiquidityPoolOwnership(address liquidityPool, address operator) external;

    function weth() external view returns (address);

    function accessController() external view returns (address);

    function symbolService() external view returns (address);
}
