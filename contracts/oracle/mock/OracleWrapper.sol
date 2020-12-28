// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract OracleWrapper {
    bool internal _isMarketClosed;
    string internal _collateral;
    string internal _underlyingAsset;
    int256 internal _indexPrice;
    uint256 internal _indexPriceTimestamp;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;

    constructor(string memory collateral_, string memory underlyingAsset_) {
        _collateral = collateral_;
        _underlyingAsset = underlyingAsset_;
    }

    function setIndexPrice(int256 price, uint256 timestamp) external {
        _indexPrice = price;
        _indexPriceTimestamp = timestamp;
    }

    function setMarkPrice(int256 price, uint256 timestamp) external {
        _markPrice = price;
        _markPriceTimestamp = timestamp;
    }

    function setMarketClosed(bool isClosed) external {
        _isMarketClosed = isClosed;
    }

    function collateral() external view returns (string memory) {
        return _collateral;
    }

    function underlyingAsset() external view returns (string memory) {
        return _underlyingAsset;
    }

    function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp) {
        return (_markPrice, _markPriceTimestamp);
    }

    function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp) {
        return (_indexPrice, _indexPriceTimestamp);
    }

    function isMarketClosed() external returns (bool) {
        return _isMarketClosed;
    }
}
