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

	function validateOrder(
		Core storage core,
		Order memory order,
		int256 amount
	) public view {
		bytes32 orderHash = order.orderHash();
		require(!core.orderCanceled[orderHash], "order is canceled");
		require(
			core.orderFilled[orderHash].add(amount) <= order.amount,
			"no enough amount to fill"
		);
		require(order.broker == msg.sender, "broker mismatch");
		require(order.relayer == tx.origin, "relayer mismatch");
		require(order.perpetual == address(this), "perpetual mismatch");
		require(order.chainID == Utils.chainID(), "chainid mismatch");
		require(order.amount == 0, "amount is 0");
		require(order.deadline() >= block.timestamp, "order is expired");
		if (order.isCloseOnly() || order.orderType() == OrderType.STOP) {
			int256 maxAmount = core.marginAccounts[address(this)].positionAmount;
			require(!Utils.hasSameSign(maxAmount, amount), "not closing order");
			require(amount.abs() <= maxAmount.abs(), "no enough amount to close");
		}
	}
}
