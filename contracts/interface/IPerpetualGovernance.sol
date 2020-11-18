// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IPerpetualGovernance {
    function updateCoreParameter(bytes32 key, int256 newValue) external;

    function updateRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external;

    function adjustRiskParameter(bytes32 key, int256 newValue) external;
}
