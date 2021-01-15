// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IPoolCreator {
    function activatePerpetualFor(address trader, uint256 perpetualIndex) external;

    function deactivatePerpetualFor(address trader, uint256 perpetualIndex) external;

    function setLiquidityPoolOwnership(address liquidityPool, address operator) external;

    function getVault() external view returns (address);

    function getVaultFeeRate() external view returns (int256);

    function getWeth() external view returns (address);

    function getAccessController() external view returns (address);

    function getSymbolService() external view returns (address);
}
