// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface IOracle {
    function symbol() external view returns (string memory);
    function collateral() external view returns (address);
	function underlyingAsset() external view returns (address);
	function priceTimeout() external view returns (uint256);
	function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp);
	function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp);
}

library ArgumentModule {
    uint256 constant private _MAX_PARAMETER_LENGTH = 14;

    function validateArguments(
        int256[_MAX_PARAMETER_LENGTH] calldata argValues,
        int256[_MAX_PARAMETER_LENGTH] calldata minArgValues,
        int256[_MAX_PARAMETER_LENGTH] calldata maxArgValues
    ) public pure {
        // min / max
        for (uint256 i = 0; i < _MAX_PARAMETER_LENGTH; i++) {
            require(argValues[i] >= minArgValues[i], "exceed min");
            require(argValues[i] <= maxArgValues[i], "exceed max");
        }
        // reserve
        require(argValues[0] > 0, "reserve required");
    }

    function validateOracleInterface(address oracle) public {
        require(oracle != address(0), "empty oracle");

        IOracle oracleLike = IOracle(oracle);
        stringAssertNotEqual(oracleLike.symbol(), "", "empty oracle symbol");
        require(oracleLike.collateral() != address(0), "invalid collateral address");
        require(oracleLike.underlyingAsset() != address(0), "invalid underlying asset address");
        {
            ( int256 price, uint256 time ) = oracleLike.priceTWAPLong();
            require(price > 0 && time > 0, "twap long returns invalid data");
        }
        {
            ( int256 price, uint256 time ) = oracleLike.priceTWAPShort();
            require(price > 0 && time > 0, "twap short returns invalid data");
        }
    }

    function stringAssertNotEqual(string memory a, string memory b, string memory error) internal pure {
        require(keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)), error);
    }
}