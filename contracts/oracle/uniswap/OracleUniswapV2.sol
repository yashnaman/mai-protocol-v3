// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import "@openzeppelin/contracts/math/SafeMath.sol";

contract OracleUniswapV2 {
	using FixedPoint for *;

    uint256 public constant PERIOD = 24 hours;

	struct PairState {
		IUniswapV2Pair pair;
		address token0;
		address token1;
		uint256 lastCumulativePrice;
		uint32 lastBlockTimestamp;
	}

    address internal immutable _collateral;
    address internal immutable _asset;

	PairState[] internal _queryState;
    FixedPoint.uq112x112 internal _averagePrice;

	// token a => collateral
	// token b => asset
    constructor(address factory, address collateral, address asset, address[] memory path) public {
		require(path.length >= 2, "");
		require(path[0] == collateral && path[path.length - 1] == asset, "");

		_collateral = collateral;
		_asset = asset;

		uint256 pathLength = path.length - 1;
		for (uint256 i = 0; i < pathLength; i++) {
			IUniswapV2Pair pair = IUniswapV2Pair(_pairFor(factory, path[i], path[i+1]));
			{
				// ensure that there's liquidity in the pair
				(
					uint112 reserve0,
					uint112 reserve1,
				) = pair.getReserves();
				require(reserve0 != 0 && reserve1 != 0, 'ExampleOracleSimple: NO_RESERVES');
			}
			address token0 = pair.token0();
			address token1 = pair.token1();
			(
				uint256 cumulativePrice,
				uint32 lastBlockTimestamp
			) = _getCurrentCumulativePrices(pair, token0, token1);
			_queryState.push(PairState({
				pair: pair,
				token0: token0,
				token1: token1,
				lastCumulativePrice: cumulativePrice,
				lastBlockTimestamp: lastBlockTimestamp
			}));
        }
    }

    function update() internal returns (uint256) {
		FixedPoint.uq112x112 memory tempAveragePrice = FixedPoint.uq112x112(uint224(1));
		uint256 pathLength = _queryState.length - 1;
        for (uint256 i = 0; i < pathLength; i++) {
			PairState memory state = _queryState[i];
			(
				uint256 cumulativePrice,
				uint32 lastBlockTimestamp
			) = _getCurrentCumulativePrices(state.pair, state.token0, state.token1);
			uint32 timeElapsed = lastBlockTimestamp - state.lastBlockTimestamp;
			FixedPoint.uq112x112 memory price =
				FixedPoint.uq112x112(uint224((cumulativePrice - state.lastCumulativePrice) / timeElapsed));
			tempAveragePrice = tempAveragePrice.muluq(price);
			_queryState[i].lastCumulativePrice = cumulativePrice;
			_queryState[i].lastBlockTimestamp = lastBlockTimestamp;
        }
		_averagePrice = tempAveragePrice;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function query(uint256 amountIn) external view returns (uint256 amountOut) {
		amountOut = _averagePrice.mul(amountIn).decode144();
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
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
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
    ) internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = _currentBlockTimestamp();
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
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