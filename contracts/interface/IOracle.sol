// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IOracle {
    function isMarketClosed() external view returns (bool);

    function isTerminated() external view returns (bool);

    function collateral() external view returns (string memory);

    function underlyingAsset() external view returns (string memory);

    function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp);

    function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp);
}
