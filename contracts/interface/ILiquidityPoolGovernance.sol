// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface ILiquidityPoolGovernance {
    function updatePerpetualParameter(bytes32 key, int256 newValue) external;

    function updatePerpetualRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external;

    function adjustPerpetualRiskParameter(bytes32 key, int256 newValue) external;
}
