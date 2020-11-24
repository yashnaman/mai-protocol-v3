// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Perpetual {
	/// slow, slow time, fast, fast time
	function price()
		public
		view
		returns (
			int256,
			uint256,
			int256,
			uint256
		)
	{
		return (int256(100 ether), block.timestamp, int256(100 ether), block.timestamp);
	}

	function oracle() public view returns (address) {
		return address(this);
	}

	function marginAccount(address)
		public
		pure
		returns (
			int256,
			int256,
			int256
		)
	{
		// cash, pos, entryFunding
		return (10000 ether, -1 ether, 0.0001 ether);
	}

	int256 internal _initialMargin = 10 ether;

	function initialMargin(address) public view returns (int256) {
		return _initialMargin;
	}

	function setInitialMargin(int256 value) public {
		_initialMargin = value;
	}

	int256 internal _maintenanceMargin = 7.5 ether;

	function maintenanceMargin(address) public view returns (int256) {
		return _maintenanceMargin;
	}

	function setMaintenanceMargin(int256 value) public {
		_maintenanceMargin = value;
	}

	int256 internal _margin = 10000 ether + 100 ether;

	function margin(address) public view returns (int256) {
		return _margin;
	}

	function setMargin(int256 value) public {
		_margin = value;
	}

	int256 internal _availableMargin = 10000 ether + 90 ether;

	function availableMargin(address) public view returns (int256) {
		return _availableMargin;
	}

	function setAvailableMargin(int256 value) public {
		_availableMargin = value;
	}

	int256 internal _withdrawableMargin;

	function withdrawableMargin(address) public view returns (int256) {
		return _withdrawableMargin;
	}

	function setWithdrawableMargin(int256 value) public {
		_withdrawableMargin = value;
	}

	event Deposit(address, int256);

	function deposit(int256 amount) public {
		emit Deposit(msg.sender, amount);
	}

	event Withdraw(address, int256);

	function withdraw(int256 amount) public {
		emit Withdraw(msg.sender, amount);
	}

	event Trade(address trader, int256 amount, int256 price);

	function trade(
		int256 amount,
		int256 priceLimit,
		uint256 deadline
	) public {
		emit Trade(msg.sender, amount, 120 ether);
	}

	event Trade2(address trader, int256 amount, int256 price, bytes data);

	function trade2(
		address trader,
		int256 amount,
		int256 priceLimit,
		uint256 deadline,
		bytes memory data
	) public {
		emit Trade2(msg.sender, amount, 120 ether, data);
	}

	enum FailureOption { REVERT, IGNORE }

	struct OrderSignature {
		bytes32 config;
		bytes32 r;
		bytes32 s;
	}

	struct Order {
		address trader;
		address broker;
		address perpetual;
		int256 price;
		int256 amount;
		uint64 expiredAt;
		uint32 version; // == 1
		uint8 category; // 0 = limit, 1 =market
		bool isCloseOnly;
		bool inversed;
		uint64 salt;
		uint64 chainId;
		OrderSignature signature;
	}

	event Match(Order, int256, int256, bool);

	function batchTrade(
		Order[] calldata orders,
		int256[] calldata amounts,
		int256[] calldata gases,
		FailureOption option
	) external {
		for (uint256 i = 0; i < orders.length; i++) {
			Order memory order = orders[i];
			trade2(order.trader, amounts[i], order.price, order.expiredAt, "0x");
			emit Match(order, amounts[i], gases[i], true);
		}
	}

	/// @return acc, last time
	function lastFundingState() public view returns (int256, uint256) {
		return (-0.0001 ether, block.timestamp);
	}
}
