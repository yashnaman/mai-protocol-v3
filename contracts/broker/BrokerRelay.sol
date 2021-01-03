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
        AddressUpgradeable.sendValue(payable(msg.sender), amount);
        emit Withdraw(msg.sender, amount);
    }

    function cancelOrder(Order memory order) public {
        bytes32 orderHash = order.getOrderHash();
        require(!_orderCanceled[orderHash], "order is already canceled");
        _orderCanceled[orderHash] = true;
        emit CancelOrder(orderHash);
    }

    function execute(
        address liqidityPool,
        bytes memory callData,
        uint256 gasReward
    ) public {
        // address signer = getSigner(callData);
        // require(gasReward <= balanceOf(order.trader), "insufficient gas fee");
        (bool success, ) = liqidityPool.call(callData);
        require(success);
        // _transfer(signer, msg.sender, gasReward);
    }

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

    function _fillOrder(bytes32 orderHash, int256 amount) internal {
        _orderFilled[orderHash] = _orderFilled[orderHash].add(amount);
        emit FillOrder(orderHash, amount);
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
}
