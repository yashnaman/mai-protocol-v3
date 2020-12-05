// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";

import "../Type.sol";

library OrderModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using OrderData for Order;

    uint32 internal constant SUPPORTED_ORDER_VERSION = 3;

    event FillOrder(Order order, bytes32 orderHash, int256 filledAmount, int256 totalAmount);
    event CancelOrder(Order order, bytes32 orderHash);

    function validateOrder(
        Market storage market,
        Order memory order,
        int256 amount
    ) public view {
        require(amount != 0, "amount is 0");

        require(order.amount != 0, "order amount is 0");
        require(Utils.hasSameSign(amount, order.amount), "side mismatch");
        require(order.broker == msg.sender, "broker mismatch");
        require(order.relayer == tx.origin, "relayer mismatch");
        require(order.perpetual == address(this), "perpetual mismatch");
        require(order.chainID == Utils.chainID(), "chainid mismatch");
        require(order.deadline() >= block.timestamp, "order is expired");
        require(order.version() == SUPPORTED_ORDER_VERSION, "order version is not supported");

        bytes32 orderHash = order.orderHash();
        require(!market.orderCanceled[orderHash], "order is canceled");
        require(
            market.orderFilled[orderHash].add(amount).abs() <= order.amount.abs(),
            "no enough amount to fill"
        );

        if (order.isCloseOnly() || order.orderType() == OrderType.STOP) {
            int256 maxAmount = market.marginAccounts[order.trader].positionAmount;
            require(!Utils.hasSameSign(maxAmount, amount), "not closing order");
            require(amount.abs() <= maxAmount.abs(), "no enough amount to close");
        }
    }

    function cancelOrder(Market storage market, Order memory order) public {
        bytes32 orderHash = order.orderHash();
        require(!market.orderCanceled[orderHash], "order is canceled");
        market.orderCanceled[orderHash] = true;
        emit CancelOrder(order, orderHash);
    }

    function fillOrder(
        Market storage market,
        Order memory order,
        int256 amount
    ) public {
        bytes32 orderHash = order.orderHash();
        market.orderFilled[orderHash] = market.orderFilled[orderHash].add(amount);
        require(
            market.orderFilled[orderHash].abs() <= order.amount.abs(),
            "no enough amount to fill"
        );
        emit FillOrder(order, orderHash, amount, order.amount);
    }
}
