// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IFactory {
    function vault() external view returns (address);

    function vaultFeeRate() external view returns (int256);

    function activateLiquidityPoolFor(address trader, uint256 perpetualIndex) external;

    function deactivateLiquidityPoolFor(address trader, uint256 perpetualIndex) external;

    function weth() external view returns (address);

    function accessController() external view returns (address);
}
