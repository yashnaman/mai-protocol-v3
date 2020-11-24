// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/OrderHash.sol";

import "../Type.sol";

contract TestOrder {
	using OrderHash for Order;

	function orderHash(Order memory order) public pure returns (bytes32) {
		return order.orderHash();
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
