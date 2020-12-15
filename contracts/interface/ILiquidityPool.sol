// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPool {
    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken
    ) external;

    function trade(
        uint256 marketIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    ) external;

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature
    ) external;
}
