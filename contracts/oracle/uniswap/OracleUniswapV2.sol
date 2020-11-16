// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import "@openzeppelin/contracts/math/SafeMath.sol";

contract OracleUniswapV2 {
	using FixedPoint for *;

	struct PairInfo {
		IUniswapV2Pair pair;
		address token0;
		address token1;
	}

	struct PriceCache {
		FixedPoint.uq112x112 lastPrice;
		FixedPoint.uq112x112 lastAveragePrice;
		uint256 lastCumulativePrice;
		uint32 lastBlockTimestamp;
	}

    address internal immutable _collateral;
    address internal immutable _asset;

	uint256 internal _fastPeriod;
	uint256 internal _slowPeriod;

	PairInfo[] internal _pairInfo;
	PriceCache[] internal _slowPriceCache;
	PriceCache[] internal _fastPriceCache;

    FixedPoint.uq112x112 internal _slowAveragePrice;
	FixedPoint.uq112x112 internal _fastAveragePrice;
	uint32 _lastUpdateTimestamp;
	uint32 _lastPriceTimestamp;

	// token a => collateral
	// token b => asset
    constructor(address factory, address asset, address collateral, address[] memory path) {
		require(path.length >= 2, "paths are too short");
		require(path[0] == asset && path[path.length - 1] == collateral, "paths must be from asset to collateral");

		_collateral = collateral;
		_asset = asset;

		uint256 pathLength = path.length - 1;
		uint32 currentBlockTimestamp = _currentBlockTimestamp();
		for (uint256 i = 0; i < pathLength; i++) {
			IUniswapV2Pair pair = IUniswapV2Pair(_pairFor(factory, path[i], path[i+1]));
			PriceCache memory initialData;
			{
				// ensure that there's liquidity in the pair
				(
					uint112 reserve0,
					uint112 reserve1,
				) = pair.getReserves();
				require(reserve0 != 0 && reserve1 != 0, 'no reserve');
				(address tokenA,) = _sortTokens(path[i], path[i+1]);
				if (tokenA == path[i]) {
					initialData.lastPrice = FixedPoint.fraction(reserve1, reserve0);
					initialData.lastAveragePrice = FixedPoint.fraction(reserve1, reserve0);
				} else {
					initialData.lastPrice = FixedPoint.fraction(reserve0, reserve1);
					initialData.lastAveragePrice = FixedPoint.fraction(reserve0, reserve1);
				}
			}
			address token0 = pair.token0();
			address token1 = pair.token1();
			(uint256 cumulativePrice, ) = _getCurrentCumulativePrices(pair, path[i], path[i+1]);
			_pairInfo.push(PairInfo({
				pair: pair,
				token0: path[i],
				token1: path[i+1]
			}));
			initialData.lastCumulativePrice = cumulativePrice;
			initialData.lastBlockTimestamp = currentBlockTimestamp;
			_slowPriceCache.push(initialData);
			_fastPriceCache.push(initialData);
        }
    }

    function _update() internal returns (bool) {
		uint32 currentBlockTimestamp = _currentBlockTimestamp();
		if (currentBlockTimestamp == _lastUpdateTimestamp) {
			return false;
		}
		FixedPoint.uq112x112 memory slowAveragePrice = FixedPoint.uq112x112(uint224(2**112));
		FixedPoint.uq112x112 memory fastAveragePrice = FixedPoint.uq112x112(uint224(2**112));
		uint256 pathLength = _pairInfo.length - 1;
        _lastPriceTimestamp = uint32(-1);
        for (uint256 i = 0; i <= pathLength; i++) {
			PairInfo memory info = _pairInfo[i];
			(
				uint256 cumulativePrice,
				uint32 lastBlockTimestamp
			) = _getCurrentCumulativePrices(info.pair, info.token0, info.token1);
			FixedPoint.uq112x112 memory slowPrice = _updatePriceCache(
				_slowPriceCache[i],
				cumulativePrice,
				currentBlockTimestamp,
				_slowPeriod
			);
			FixedPoint.uq112x112 memory fastPrice = _updatePriceCache(
				_fastPriceCache[i],
				cumulativePrice,
				currentBlockTimestamp,
				_fastPeriod
			);
			slowAveragePrice = slowAveragePrice.muluq(slowPrice);
			fastAveragePrice = fastAveragePrice.muluq(fastPrice);
			if (lastBlockTimestamp < _lastPriceTimestamp) {
				_lastPriceTimestamp = lastBlockTimestamp;
			}
        }
		_slowAveragePrice = slowAveragePrice;
		_fastAveragePrice = fastAveragePrice;
		_lastUpdateTimestamp = currentBlockTimestamp;
		return true;
    }

	function _updatePriceCache(
		PriceCache storage priceCache,
		uint256 cumulativePrice,
		uint32 currentBlockTimestamp,
		uint256 updatePeriod
	) internal returns (FixedPoint.uq112x112 memory) {
		if (currentBlockTimestamp == priceCache.lastBlockTimestamp) {
			return priceCache.lastPrice;
		}
		FixedPoint.uq112x112 memory price = _getAveragePrice(priceCache, cumulativePrice, currentBlockTimestamp);
		if (currentBlockTimestamp - priceCache.lastBlockTimestamp >= updatePeriod) {
			priceCache.lastAveragePrice = price;
			priceCache.lastCumulativePrice = cumulativePrice;
			priceCache.lastBlockTimestamp = currentBlockTimestamp;
		}
		priceCache.lastPrice = price;
		return price;
	}

	function _getAveragePrice(
		PriceCache storage priceCache,
		uint256 cumulativePrice,
		uint32 lastBlockTimestamp
	) internal view returns (FixedPoint.uq112x112 memory) {
		uint32 timeElapsed = lastBlockTimestamp - priceCache.lastBlockTimestamp;
		FixedPoint.uq112x112 memory price =
			FixedPoint.uq112x112(uint224((cumulativePrice - priceCache.lastCumulativePrice) / timeElapsed));
		return FixedPoint.uq112x112(uint224((price._x + priceCache.lastAveragePrice._x) / 2));
	}

	/// @dev Return cumulativePrice of token0.
	function _getCurrentCumulativePrices(
		IUniswapV2Pair pair,
		address token0,
		address token1
	) internal view returns (uint256, uint32) {
		(address tokenA,) = _sortTokens(token0, token1);
		(
			uint256 cumulativePrice0,
			uint256 cumulativePrice1,
			uint32 lastBlockTimestamp
		) = _currentCumulativePrices(pair);
		return (tokenA == token0 ? cumulativePrice0 : cumulativePrice1, lastBlockTimestamp);
	}

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'identical addresses');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'zero addess');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function _pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = address(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function _currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function _currentCumulativePrices(
        IUniswapV2Pair pair
    ) internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestampLast) {
        uint32 blockTimestamp = _currentBlockTimestamp();
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();

		uint112 reserve0;
		uint112 reserve1;
        // if time has elapsed since the last update on the pair, mock the accumulated price values
        ( reserve0,  reserve1, blockTimestampLast) = pair.getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}
