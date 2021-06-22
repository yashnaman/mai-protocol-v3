// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract OracleUniswapV2 {
    struct PoolInfo {
        address pool;
        bool inverse;
    }

    string internal _collateral;
    string internal _underlyingAsset;
    uint32 internal _shortPeriod;
    uint32 internal _longPeriod;
    PoolInfo[] internal _poolInfo;

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

        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool =
                PoolAddress.computeAddress(
                    factory,
                    PoolAddress.getPoolKey(path[i], path[i + 1], fees[i])
                );
            _poolInfo[i] = PoolInfo({ pool: pool, inverse: path[i] > path[i + 1] });
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
        newPrice = 10**18;
        uint256 length = _poolInfo.length;
        for (uint256 i = 0; i < length; i++) {
            PoolInfo memory poolInfo = _poolInfo[i];
            int24 tick = OracleLibrary.consult(poolInfo.pool, period);
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
            if (sqrtRatioX96 <= type(uint128).max) {
                uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
                newPrice = poolInfo.inverse
                    ? FullMath.mulDiv(1 << 192, newPrice, ratioX192)
                    : FullMath.mulDiv(ratioX192, newPrice, 1 << 192);
            } else {
                uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
                newPrice = poolInfo.inverse
                    ? FullMath.mulDiv(1 << 128, newPrice, ratioX128)
                    : FullMath.mulDiv(ratioX128, newPrice, 1 << 128);
            }
        }
        newTimestamp = block.timestamp;
    }
}
