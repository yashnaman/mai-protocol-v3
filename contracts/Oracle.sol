// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Context.sol";
import "./Type.sol";

import "./interface/IOracle.sol";

contract Oracle is Context {
    address internal _oracle;
    OraclePriceData internal _indexPriceCache;
    OraclePriceData internal _marketPriceCache;

    function __OracleInitialize(address oracle) internal {
        _oracle = oracle;
    }

    function _markPrice() internal returns (int256 price) {
        return _markPriceData().price;
    }

    function _markPriceData()
        internal
        virtual
        returns (OraclePriceData memory)
    {
        if (_now() != _marketPriceCache.timestamp) {
            (int256 price, uint256 time) = IOracle(_oracle).priceTWAPLong();
            _marketPriceCache = OraclePriceData({
                price: price,
                timestamp: time
            });
        }
        return _marketPriceCache;
    }

    function _indexPrice() internal returns (int256 price) {
        return _indexPriceData().price;
    }

    function _indexPriceData()
        internal
        virtual
        returns (OraclePriceData memory)
    {
        if (_now() != _indexPriceCache.timestamp) {
            (int256 price, uint256 time) = IOracle(_oracle).priceTWAPShort();
            _indexPriceCache = OraclePriceData({price: price, timestamp: time});
        }
        return _indexPriceCache;
    }

    bytes32[50] private __gap;
}
