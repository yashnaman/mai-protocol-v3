// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/OrderData.sol";

import "../module/OrderModule.sol";

import "../Type.sol";
import "../Storage.sol";

contract TestOrder is Storage {
    using OrderData for Order;
    using OrderData for bytes;
    using OrderModule for LiquidityPoolStorage;

    constructor() {
        _liquidityPool.perpetuals.push();
    }

    function decompress(bytes memory data)
        public
        pure
        returns (Order memory order, bytes memory signature)
    {
        order = data.decodeOrderData();
        signature = data.decodeSignature();
    }

    function orderHash(Order memory order) public pure returns (bytes32) {
        return order.getOrderHash();
    }

    function isCloseOnly(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function isMarketOrder(Order memory order) public pure returns (bool) {
        return order.isMarketOrder();
    }

    function isStopLossOrder(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function isTakeProfitOrder(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function salt(Order memory order) public pure returns (uint64) {
        return order.salt;
    }

    function getSigner(
        Order memory order,
        bytes memory signature,
        uint8 signType
    ) public pure returns (address) {
        return order.getSigner(signature);
    }

    function validateSignature(
        Order memory order,
        bytes memory signature,
        uint8 signType
    ) public view {
        _liquidityPool.validateSignature(order, signature);
    }

    function validateOrder(Order memory order, int256 amount) public view {
        _liquidityPool.validateOrder(order, amount);
    }

    function validateTriggerPrice(Order memory order) public view {
        _liquidityPool.validateTriggerPrice(order);
    }

    function setPositionAmount(address trader, int256 amount) public {
        _liquidityPool.perpetuals[0].marginAccounts[trader].position = amount;
    }
}
