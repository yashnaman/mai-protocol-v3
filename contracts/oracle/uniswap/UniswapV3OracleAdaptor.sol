// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../interface/IOracle.sol";

interface IERC20 {
    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract UniswapV3OracleAdaptor is IOracle {
    using Address for address;

    string public override collateral;
    string public override underlyingAsset;
    uint32 public shortPeriod;
    uint32 public longPeriod;
    address[] public pools;
    address[] public path;
    uint8 internal collateralDecimals;
    uint8 internal underlyingAssetDecimals;

    constructor(
        address factory_,
        address[] memory path_,
        uint24[] memory fees_,
        uint32 shortPeriod_,
        uint32 longPeriod_
    ) {
        uint256 pathLength = path_.length;
        require(pathLength >= 2, "paths are too short");
        require(pathLength - 1 == fees_.length, "paths and fees are mismatched");

        collateral = IERC20(path_[pathLength - 1]).symbol();
        collateralDecimals = IERC20(path_[pathLength - 1]).decimals();
        underlyingAsset = IERC20(path_[0]).symbol();
        underlyingAssetDecimals = IERC20(path_[0]).decimals();
        require(collateralDecimals <= 18 && underlyingAssetDecimals <= 18, "decimals over 18");
        longPeriod = longPeriod_;
        shortPeriod = shortPeriod_;
        path = path_;

        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool = PoolAddress.computeAddress(
                factory_,
                PoolAddress.getPoolKey(path[i], path[i + 1], fees_[i])
            );
            require(pool.isContract(), "pool not exists");
            pools.push(pool);
        }
    }

    function isMarketClosed() public pure override returns (bool) {
        return false;
    }

    function isTerminated() public pure override returns (bool) {
        return false;
    }

    function priceTWAPLong() public view override returns (int256, uint256) {
        return priceTWAP(longPeriod);
    }

    function priceTWAPShort() public view override returns (int256, uint256) {
        return priceTWAP(shortPeriod);
    }

    function priceTWAP(uint32 period)
        internal
        view
        returns (int256 newPrice, uint256 newTimestamp)
    {
        // input = 1, output = price
        uint128 baseAmount = uint128(10**underlyingAssetDecimals);
        uint256 length = pools.length;
        for (uint256 i = 0; i < length; i++) {
            int24 tick = OracleLibrary.consult(pools[i], period);
            uint256 quoteAmount = OracleLibrary.getQuoteAtTick(
                tick,
                baseAmount,
                path[i],
                path[i + 1]
            );
            baseAmount = SafeCast.toUint128(quoteAmount);
        }
        // change to 18 decimals for mcdex oracle interface
        newPrice = int256(baseAmount * 10**(18 - collateralDecimals));
        newTimestamp = block.timestamp;
    }
}
