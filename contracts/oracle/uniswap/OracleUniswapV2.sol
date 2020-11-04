// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract OracleUniswapV2 {

	string internal _name;
	address internal _uniswapPair;
	address internal _asset;
	address internal _collateral;

	constructor(
		string memory name,
		address uniswapPair,
		address collateral
	) public {

	}


	function pair()
    function Symbol() public view returns (uint256);
    function collateral() public view (address)
	function asset() public view (address)
	function priceTimeout() (uint256)
	function priceTWAPLong() (uint256 newPrice, uint256 newTimestamp);
	function priceTWAPShort() (uint256 newPrice, uint256 newTimestamp);
}