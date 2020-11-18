// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../interface/IOracle.sol";

contract OracleWrapper is IOracle {

    address internal _collateral;
    int256 internal _indexPrice;
    uint256 internal _indexPriceTimestamp;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;

    constructor(address collateralToken) {
        _collateral = collateralToken;
    }

    function setIndexPrice(int256 price, uint256 timestamp) external {
        _indexPrice = price;
        _indexPriceTimestamp = timestamp;
    }

    function setMarkPrice(int256 price, uint256 timestamp) external {
        _markPrice = price;
        _markPriceTimestamp = timestamp;
    }

    function collateral() external view override returns (address) {
        return _collateral;
    }

	function underlyingAsset() external view override returns (string memory) {
        return "MTK";
    }

	function priceTWAPLong() external override returns (int256 newPrice, uint256 newTimestamp) {
        return (_markPrice, _markPriceTimestamp);
    }

	function priceTWAPShort() external override returns (int256 newPrice, uint256 newTimestamp) {
        return (_indexPrice, _indexPriceTimestamp);
    }

}