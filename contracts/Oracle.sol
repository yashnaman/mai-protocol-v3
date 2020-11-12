// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Context.sol";
import "./Type.sol";

// import "./module/ArgumentModule.sol";

interface IPriceOracle {
    function symbol() external view returns (uint256);
    function collateral() external view returns (address);
	function underlyingAsset() external view returns (address);
	function priceTimeout() external view returns (uint256);
	function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp);
	function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp);
}

contract Oracle is Context {

    address internal _oracle;
    OraclePriceData internal _indexPriceCache;
    OraclePriceData internal _marketPriceCache;

    function __OracleInitialize(address oracle) internal {
        // ArgumentModule.validateOracleInterface(oracle);
        _oracle = oracle;
    }

    function _markPrice() internal returns (int256 price) {
        return _markPriceData().price;
    }

    function _markPriceData() internal returns (OraclePriceData memory) {
        if (_now() != _marketPriceCache.timestamp) {
            ( int256 price, uint256 time) = IPriceOracle(_oracle).priceTWAPLong();
            _marketPriceCache = OraclePriceData({ price: price, timestamp: time });
        }
        return _marketPriceCache;
    }

    function _indexPrice() internal returns (int256 price) {
        return _indexPriceData().price;
    }

    function _indexPriceData() internal returns (OraclePriceData memory) {
        if (_now() != _indexPriceCache.timestamp) {
            ( int256 price, uint256 time) = IPriceOracle(_oracle).priceTWAPShort();
            _indexPriceCache = OraclePriceData({ price: price, timestamp: time });
        }
        return _indexPriceCache;
    }

    bytes32[50] private __gap;
}