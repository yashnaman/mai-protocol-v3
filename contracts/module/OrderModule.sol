// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";

import "../module/MarginModule.sol";

import "../Type.sol";

library OrderModule {
    using SignedSafeMathUpgradeable for int256;
    using SafeMathExt for int256;
    using OrderData for Order;
    using MarginModule for Market;

    uint32 internal constant SUPPORTED_ORDER_VERSION = 3;

    event FillOrder(Order order, bytes32 orderHash, int256 filledAmount, int256 totalAmount);
    event CancelOrder(Order order, bytes32 orderHash);

    function validateOrder(
        Core storage core,
        Order memory order,
        int256 amount
    ) public view {
        require(amount != 0, "amount is 0");

        require(order.amount != 0, "order amount is 0");
        require(Utils.hasSameSign(amount, order.amount), "side mismatch");
        require(order.broker == msg.sender, "broker mismatch");
        require(order.relayer == tx.origin, "relayer mismatch");
        require(order.liquidityPool == address(this), "liquidityPool mismatch");
        require(order.chainID == Utils.chainID(), "chainid mismatch");
        require(order.deadline() >= block.timestamp, "order is expired");
        require(order.version() == SUPPORTED_ORDER_VERSION, "order version is not supported");

        bytes32 orderHash = order.orderHash();
        require(!core.orderCanceled[orderHash], "order is canceled");
        require(
            core.orderFilled[orderHash].add(amount).abs() <= order.amount.abs(),
            "no enough amount to fill"
        );
    }

    function truncateAmount(
        Core storage core,
        uint256 marketIndex,
        address trader,
        int256 amount
    ) public view returns (int256 alignedAmount) {
        int256 maxAmount = core.markets[marketIndex].positionAmount(trader);
        require(!Utils.hasSameSign(maxAmount, amount), "not closing order");
        require(amount.abs() <= maxAmount.abs(), "no enough amount to close");
        alignedAmount = amount.abs() > maxAmount.abs() ? maxAmount : amount;
    }

    function cancelOrder(Core storage core, Order memory order) public {
        bytes32 orderHash = order.orderHash();
        require(!core.orderCanceled[orderHash], "order is canceled");
        core.orderCanceled[orderHash] = true;
        emit CancelOrder(order, orderHash);
    }

    function fillOrder(
        Core storage core,
        Order memory order,
        int256 amount
    ) public {
        bytes32 orderHash = order.orderHash();
        core.orderFilled[orderHash] = core.orderFilled[orderHash].add(amount);
        require(
            core.orderFilled[orderHash].abs() <= order.amount.abs(),
            "no enough amount to fill"
        );
        emit FillOrder(order, orderHash, amount, order.amount);
    }
}
