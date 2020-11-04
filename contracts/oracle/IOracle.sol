// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

abstract contract IOracle {
    function Symbol() public view returns (uint256);
    function collateral() public view (address)
	function underlyingAsset() public view (address)
	function priceTimeout() (uint256)
	function priceTWAPLong() (uint256 newPrice, uint256 newTimestamp);
	function priceTWAPShort() (uint256 newPrice, uint256 newTimestamp);
}