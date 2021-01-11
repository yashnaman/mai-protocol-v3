// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../interface/ILiquidityPool.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";

import "../Type.sol";

contract BrokerRelay is ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using OrderData for Order;
    using OrderData for bytes;

    uint256 internal constant GWEI = 10**9;

    uint256 internal _chainID;
    uint256 internal _claimableFees;
    mapping(address => uint256) internal _balances;
    mapping(bytes32 => int256) internal _orderFilled;
    mapping(bytes32 => bool) internal _orderCanceled;

    event Deposit(address trader, uint256 amount);
    event Withdraw(address trader, uint256 amount);
    event Transfer(address sender, address recipient, uint256 amount);
    event TradeFailed(bytes32 orderHash, Order order, int256 amount, string reason);
    event TradeSuccess(bytes32 orderHash, Order order, int256 amount, uint256 gasReward);
    event CancelOrder(bytes32 orderHash);
    event FillOrder(bytes32 orderHash, int256 fillAmount);

    constructor() {
        _chainID = Utils.chainID();
    }

    /**
     * @notice Receive eth, call the deposit() function
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Get the balance of eth the trader deposited
     * @param trader The address of the trader
     * @return uint256 The balance of eth the trader deposited
     */
    function balanceOf(address trader) public view returns (uint256) {
        return _balances[trader];
    }

    /**
     * @notice Deposit eth as gas reward of the broker
     */
    function deposit() public payable nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw eth the trader deposited
     * @param amount The amount of eth to withdraw
     */
    function withdraw(uint256 amount) public nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        AddressUpgradeable.sendValue(payable(msg.sender), amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice TODO: 现在能cancel别人的单
     * @param order The order to cancel
     */
    function cancelOrder(Order memory order) public {
        bytes32 orderHash = order.getOrderHash();
        require(!_orderCanceled[orderHash], "order is already canceled");
        _orderCanceled[orderHash] = true;
        emit CancelOrder(orderHash);
    }

    /**
     * @notice Execute a transaction of liquidity pool's method
     * @param liquidityPool The address of liquidity pool
     * @param callData The call data of transaction
     * @param gasReward The gas reward given to msg.sender
     */
    function execute(
        address liquidityPool,
        bytes memory callData,
        uint256 gasReward
    ) public {
        // address signer = getSigner(callData);
        // require(gasReward <= balanceOf(order.trader), "insufficient gas fee");
        (bool success, ) = liquidityPool.call(callData);
        require(success);
        // _transfer(signer, msg.sender, gasReward);
    }

    /**
     * @notice Trade multiple orders
     * @param compressedOrders The orders to trade
     * @param amounts The trading amounts of position
     * @param gasRewards The gas rewards of eth given to the brokers
     */
    function batchTrade(
        bytes[] calldata compressedOrders,
        int256[] calldata amounts,
        uint256[] calldata gasRewards
    ) external {
        uint256 orderCount = compressedOrders.length;
        for (uint256 i = 0; i < orderCount; i++) {
            Order memory order = compressedOrders[i].decodeOrderData();
            int256 amount = amounts[i];
            uint256 gasReward = gasRewards[i];
            bytes32 orderHash = order.getOrderHash();
            require(order.chainID == _chainID, "chain id mismatch");
            require(!_orderCanceled[orderHash], "order is canceled");
            require(
                _orderFilled[orderHash].add(amount).abs() <= order.amount.abs(),
                "no enough amount to fill"
            );
            if (gasReward > balanceOf(order.trader)) {
                emit TradeFailed(orderHash, order, amount, "insufficient fee");
                return;
            }
            if (gasReward > order.brokerFeeLimit * GWEI) {
                emit TradeFailed(orderHash, order, amount, "fee exceeds trade gas limit");
                return;
            }
            if (amount.abs() < order.minTradeAmount) {
                emit TradeFailed(orderHash, order, amount, "amount is less than min trade amount");
                return;
            }
            try
                ILiquidityPool(order.liquidityPool).brokerTrade(compressedOrders[i], amount)
            returns (int256 filledAmount) {
                _fillOrder(orderHash, filledAmount);
                _transfer(order.trader, order.broker, gasReward);
                emit TradeSuccess(orderHash, order, filledAmount, gasReward);
            } catch Error(string memory reason) {
                console.log("FAILED", reason);
                emit TradeFailed(orderHash, order, amount, reason);
                return;
            } catch {
                console.log("FAILED transaction failed");
                emit TradeFailed(orderHash, order, amount, "transaction failed");
                return;
            }
        }
    }

    /**
     * @dev Update the filled position amount of the order
     * @param orderHash The hash of the order
     * @param amount The filled amount of position to update
     */
    function _fillOrder(bytes32 orderHash, int256 amount) internal {
        _orderFilled[orderHash] = _orderFilled[orderHash].add(amount);
        emit FillOrder(orderHash, amount);
    }

    /**
     * @dev Transfer from sender's balance to recipient's balance
     * @param sender The address of the sender
     * @param recipient The address of the recipient
     * @param amount The amount of eth transferred
     */
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
}
