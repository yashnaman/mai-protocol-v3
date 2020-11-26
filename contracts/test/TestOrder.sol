// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/OrderData.sol";

import "../Type.sol";

contract TestOrder {
	using OrderData for Order;

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
}
