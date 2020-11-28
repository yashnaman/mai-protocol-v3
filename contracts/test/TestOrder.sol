// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/OrderData.sol";

import "../module/OrderModule.sol";

import "../Type.sol";
import "../Storage.sol";

contract TestOrder is Storage {
    using OrderData for Order;
    using OrderModule for Core;

    function orderHash(Order memory order) public pure returns (bytes32) {
        return order.orderHash();
    }

    function deadline(Order memory order) public pure returns (uint64) {
        return order.deadline();
    }

    function version(Order memory order) public pure returns (uint32) {
        return order.version();
    }

    function orderType(Order memory order) public pure returns (OrderType) {
        return order.orderType();
    }

    function isCloseOnly(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function salt(Order memory order) public pure returns (uint64) {
        return order.salt();
    }

    function orderHashDebug(Order memory order)
        public
        pure
        returns (
            bytes32,
            bytes32,
            bytes32
        )
    {
        return order.orderHashDebug();
    }

    function cancelOrder(Order memory order) public {
        _core.cancelOrder(order);
    }

    function fillOrder(Order memory order, int256 amount) public {
        _core.fillOrder(order, amount);
    }

    function validateOrder(Order memory order, int256 amount) public view {
        _core.validateOrder(order, amount);
    }

    function setPositionAmount(address trader, int256 amount) public {
        _core.marginAccounts[trader].positionAmount = amount;
    }
}
