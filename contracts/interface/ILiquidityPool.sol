// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface ILiquidityPool {
    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken
    ) external;
}
