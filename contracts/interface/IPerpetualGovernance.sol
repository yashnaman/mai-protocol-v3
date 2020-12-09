// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IPerpetualGovernance {
    function updateMarketParameter(bytes32 key, int256 newValue) external;

    function updateMarketRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external;

    function adjustMarketRiskParameter(bytes32 key, int256 newValue) external;
}
