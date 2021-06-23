// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

interface IERC20 {
    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract UniswapV3OracleAdaptor {
    string internal _collateral;
    string internal _underlyingAsset;
    uint32 internal _shortPeriod;
    uint32 internal _longPeriod;
    address[] internal _pools;
    address[] internal _path;

    constructor(
        address factory,
        address[] memory path,
        uint24[] memory fees,
        uint32 shortPeriod_,
        uint32 longPeriod_
    ) {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "paths are too short");
        require(pathLength - 1 == fees.length, "paths and fees are mismatched");

        _collateral = IERC20(path[pathLength - 1]).symbol();
        _underlyingAsset = IERC20(path[0]).symbol();
        _longPeriod = longPeriod_;
        _shortPeriod = shortPeriod_;
        _path = path;

        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool =
                PoolAddress.computeAddress(
                    factory,
                    PoolAddress.getPoolKey(path[i], path[i + 1], fees[i])
                );
            _pools.push(pool);
        }
    }

    function isMarketClosed() public pure returns (bool) {
        return false;
    }

    function isTerminated() public pure returns (bool) {
        return false;
    }

    function collateral() public view returns (string memory) {
        return _collateral;
    }

    function underlyingAsset() public view returns (string memory) {
        return _underlyingAsset;
    }

    function longPeriod() public view returns (uint32) {
        return _longPeriod;
    }

    function shortPeriod() public view returns (uint32) {
        return _shortPeriod;
    }

    function priceTWAPLong() public view returns (uint256 newPrice, uint256 newTimestamp) {
        return priceTWAP(_longPeriod);
    }

    function priceTWAPShort() public view returns (uint256 newPrice, uint256 newTimestamp) {
        return priceTWAP(_shortPeriod);
    }

    function priceTWAP(uint32 period)
        internal
        view
        returns (uint256 newPrice, uint256 newTimestamp)
    {
        uint128 baseAmount = uint128(10**IERC20(_path[0]).decimals());
        uint256 length = _pools.length;
        uint256 quoteAmount;
        for (uint256 i = 0; i < length; i++) {
            int24 tick = OracleLibrary.consult(_pools[i], period);
            quoteAmount = OracleLibrary.getQuoteAtTick(tick, baseAmount, _path[i], _path[i + 1]);
            baseAmount = SafeCast.toUint128(quoteAmount);
        }
        newPrice = quoteAmount * 10**(18 - IERC20(_path[_path.length - 1]).decimals());
        newTimestamp = block.timestamp;
    }
}
