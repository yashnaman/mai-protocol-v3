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

	event Deposit(address trader, uint256 amount);
	event Withdraw(address trader, uint256 amount);
	event Transfer(address sender, address recipient, uint256 amount);
	event TradeFailed(bytes32 orderHash, Order order, int256 amount);
	event TradeSuccess(bytes32 orderHash, Order order, int256 amount, uint256 gasReward);

	// constructor() {
	//     _chainID = Utils.chainID();
	// }

	receive() external payable {
		deposit();
	}

	function balanceOf(address trader) public view returns (uint256) {
		return _balances[trader];
	}

	function deposit() public payable nonReentrant {
		_balances[msg.sender] = _balances[msg.sender].add(msg.value);
		emit Deposit(msg.sender, msg.value);
	}

	function withdraw(uint256 amount) public nonReentrant {
		_balances[msg.sender] = _balances[msg.sender].sub(amount);
		Address.sendValue(payable(msg.sender), amount);
		emit Withdraw(msg.sender, amount);
	}

	function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal {
		if (amount == 0) {
			return;
		}
		require(_balances[sender] >= amount, "insufficient fee");
		_balances[sender] = _balances[sender].sub(amount);
		_balances[recipient] = _balances[recipient].add(amount);
		emit Transfer(sender, recipient, amount);
	}

	function batchTrade(
		Order[] calldata orders,
		int256[] calldata amounts,
		bytes[] calldata signatures,
		uint256[] calldata gasRewards
	) external {
		uint256 orderCount = orders.length;
		for (uint256 i = 0; i < orderCount; i++) {
			uint256 gasReward = gasRewards[i];
			require(gasRewards[i] <= balanceOf(orders[i].trader), "insufficient fee");
			Order memory order = orders[i];
			int256 amount = amounts[i];
			bytes32 orderHash = order.orderHash();
			(bool success, ) = order.perpetual.call(
				abi.encodeWithSignature(
					"brokerTrade(Order,int256,bytes)",
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
