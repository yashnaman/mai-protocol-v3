// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OracleWrapper is Ownable {
    bool internal _isMarketClosed;
    bool internal _isTerminated;
    string internal _collateral;
    string internal _underlyingAsset;
    int256 internal _indexPrice;
    uint256 internal _indexPriceTimestamp;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;

    constructor(string memory collateral_, string memory underlyingAsset_) Ownable() {
        _collateral = collateral_;
        _underlyingAsset = underlyingAsset_;
    }

    function setIndexPrice(int256 price, uint256 timestamp) external onlyOwner {
        _indexPrice = price;
        _indexPriceTimestamp = timestamp;
    }

    function setMarkPrice(int256 price, uint256 timestamp) external onlyOwner {
        _markPrice = price;
        _markPriceTimestamp = timestamp;
    }

    function setMarketClosed(bool isClosed_) external onlyOwner {
        _isMarketClosed = isClosed_;
    }

    function setTerminated(bool isTerminated_) external onlyOwner {
        _isTerminated = isTerminated_;
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

    function isTerminated() external returns (bool) {
        return _isTerminated;
    }
}
