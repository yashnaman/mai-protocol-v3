// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../libraries/OrderHash.sol";
import "../Type.sol";

contract BrokerRelay is ReentrancyGuard {
	using SafeMath for uint256;
	using SafeMathExt for int256;
	using SignedSafeMath for int256;
	using OrderHash for Order;

	uint256 internal _claimableFee;
	mapping(address => uint256) internal _balances;

	uint32 public constant SUPPORTED_MIN_ORDER_VERSION = 1;
	uint32 public constant SUPPORTED_MAX_ORDER_VERSION = 1;

	uint256 internal _chainID;
	event TradeFailed(bytes32 orderHash, Order order, int256 amount);
	event TradeSuccess(bytes32 orderHash, Order order, int256 amount, uint256 gasReward);

	// constructor() {
	//     _chainID = Utils.chainID();
	// }

	function deposit() external payable nonReentrant {
		_balances[msg.sender] = _balances[msg.sender].add(msg.value);
	}

	function withdraw(uint256 amount) external nonReentrant {
		_balances[msg.sender] = _balances[msg.sender].sub(amount);
		Address.sendValue(payable(msg.sender), amount);
	}

	function _transfer(
		address spender,
		address recipient,
		uint256 gasAmount
	) internal {
		if (gasAmount == 0) {
			return;
		}
		require(_balances[spender] >= gasAmount, "");
		_balances[spender] = _balances[spender].sub(gasAmount);
		_balances[recipient] = _balances[recipient].add(gasAmount);
	}

	function batchTrade(
		Order[] calldata orders,
		int256[] calldata amounts,
		bytes32[] calldata signatures,
		uint256[] calldata gasRewards
	) external {
		uint256 orderCount = orders.length;
		uint256 currentTime = block.timestamp;
		for (uint256 i = 0; i < orderCount; i++) {
			require(orders[i].chainID == _chainID, "");
			require(orders[i].broker == address(this), "");
			require(orders[i].relayer == msg.sender, "");
			require(orders[i].deadline >= currentTime, "");
			require(amounts[i] != 0, "");
			require(gasRewards[i] > _balances[orders[i].trader], "");
		}

		for (uint256 i = 0; i < orderCount; i++) {
			Order memory order = orders[i];
			int256 amount = amounts[i];
			uint256 gasReward = gasRewards[i];
			bytes32 orderHash = order.orderHash();
			(bool success, ) = order.perpetual.call(
				abi.encodeWithSignature(
					"brokerTrade(Order,int256,bytes32)",
					order,
					amount,
					signatures
				)
			);

			if (success) {
				_transfer(order.trader, order.broker, gasReward);
				emit TradeSuccess(orderHash, order, amount, gasReward);
			} else {
				emit TradeFailed(orderHash, order, amount);
				return;
			}
		}
	}
}
