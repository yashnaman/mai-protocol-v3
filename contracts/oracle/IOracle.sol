// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IOracle {
    function symbol() external view returns (uint256);
    function collateral() external view returns (address);
	function underlyingAsset() external view returns (address);
	function priceTimeout() external view returns (uint256);
	function priceTWAPLong() external returns (uint256 newPrice, uint256 newTimestamp);
	function priceTWAPShort() external returns (uint256 newPrice, uint256 newTimestamp);
}