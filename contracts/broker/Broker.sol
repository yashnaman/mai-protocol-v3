// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

import "../interface/ILiquidityPool.sol";
import "../interface/IAccessControll.sol";
import "../interface/IPoolCreator.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";

import "../Type.sol";

interface ICallee {
    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasFeeLimit,
        bytes memory signature
    ) external;
}

contract Broker is ReentrancyGuard {
    using Address for address;
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using OrderData for Order;
    using OrderData for bytes;

    uint256 internal constant GWEI = 10**9;

    uint256 internal _chainID;
    uint256 internal _claimableFees;
    mapping(address => uint32) internal _nonces;
    mapping(address => uint256) internal _balances;
    mapping(bytes32 => int256) internal _orderFilled;
    mapping(bytes32 => bool) internal _orderCanceled;

    event Deposit(address indexed trader, uint256 amount);
    event Withdraw(address indexed trader, uint256 amount);
    event Transfer(address indexed sender, address indexed recipient, uint256 amount);
    event TradeFailed(bytes32 orderHash, Order order, int256 amount, string reason);
    event TradeSuccess(bytes32 orderHash, Order order, int256 amount, uint256 gasReward);
    event CancelOrder(bytes32 orderHash);
    event FillOrder(bytes32 orderHash, int256 fillAmount);
    event CallFunction(
        bytes32 userData1,
        bytes32 userData2,
        string functionSignature,
        bytes callData,
        bytes signature
    );

    constructor() {
        _chainID = Utils.chainID();
    }

    /**
     * @notice Sending eth to this contract is equivalent to depositing eth to the account of sender
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Get the eth balance of the trader's account
     * @param trader The address of the trader
     * @return uint256 The eth balance of the trader's account
     */
    function balanceOf(address trader) public view returns (uint256) {
        return _balances[trader];
    }

    /**
     * @notice Deposit eth to the account of sender as gas reward of the broker
     */
    function deposit() public payable nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw eth from the account of sender
     * @param amount The amount of eth to withdraw
     */
    function withdraw(uint256 amount) public nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        Address.sendValue(payable(msg.sender), amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Cancel the order. Canceled order is not able to be filled.
     *         Only order.trader / order.relayer and anthorized account (by order.trader)
     *         are able to cancel the order
     * @param order The order object to cancel
     */
    function cancelOrder(Order memory order) public {
        if (msg.sender != order.trader || msg.sender != order.relayer) {
            (, , address[7] memory addresses, , , ) =
                ILiquidityPool(order.liquidityPool).getLiquidityPoolInfo();
            IAccessControll accessControl =
                IAccessControll(IPoolCreator(addresses[0]).getAccessController());
            bool isGranted =
                accessControl.isGranted(order.trader, msg.sender, Constant.PRIVILEGE_TRADE);
            require(isGranted, "sender must be trader or relayer or authorized");
        }
        bytes32 orderHash = order.getOrderHash();
        require(!_orderCanceled[orderHash], "order is already canceled");
        _orderCanceled[orderHash] = true;
        emit CancelOrder(orderHash);
    }

    function getNonce(address account) public view returns (uint32 nonce) {
        return _nonces[account];
    }

    function callFunction(
        bytes32 userData1,
        bytes32 userData2,
        string memory method,
        bytes memory callData,
        bytes memory signature
    ) public {
        (address account, uint32 nonce, uint32 expiration, uint32 gasFeeLimit) =
            _decodeUserData1(userData1);
        (address to, uint32 gasFee) = _decodeUserData2(userData2);
        require(_getGasFee(gasFee) <= balanceOf(account), "insufficient gas fee");
        require(gasFee <= gasFeeLimit, "fee exceeds limit");
        require(expiration >= block.timestamp, "expired");
        require(nonce == _nonces[account], "non-continuous nonce");
        ICallee(to).callFunction(
            account,
            method,
            callData,
            nonce,
            expiration,
            _getGasFee(gasFeeLimit),
            signature
        );
        _nonces[account]++;
        Address.sendValue(payable(msg.sender), _getGasFee(gasFee));
        emit CallFunction(userData1, userData2, method, callData, signature);
    }

    /**
     * @notice Trade multiple orders, each order will be treated seperately
     * @param compressedOrders The compressed order objects to trade
     * @param amounts The trading amounts of position
     * @param gasRewards The gas rewards of eth given to their brokers
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
            if (order.chainID != _chainID) {
                emit TradeFailed(orderHash, order, amount, "chain id mismatch");
                return;
            }
            if (_orderCanceled[orderHash]) {
                emit TradeFailed(orderHash, order, amount, "order is canceled");
                return;
            }
            if (_orderFilled[orderHash].add(amount).abs() > order.amount.abs()) {
                emit TradeFailed(orderHash, order, amount, "no enough amount to fill");
                return;
            }
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
                _transfer(order.trader, order.relayer, gasReward);
                emit TradeSuccess(orderHash, order, filledAmount, gasReward);
            } catch Error(string memory reason) {
                emit TradeFailed(orderHash, order, amount, reason);
                return;
            } catch {
                emit TradeFailed(orderHash, order, amount, "transaction failed");
                return;
            }
        }
    }

    /**
     * @dev Update the filled position amount of the order
     * @param orderHash The hash of the order
     * @param amount The changed amount of filled position
     */
    function _fillOrder(bytes32 orderHash, int256 amount) internal {
        _orderFilled[orderHash] = _orderFilled[orderHash].add(amount);
        emit FillOrder(orderHash, amount);
    }

    /**
     * @dev Transfer eth from sender's account to recipient's account
     * @param sender The address of the sender
     * @param recipient The address of the recipient
     * @param amount The amount of eth to transfer
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

    function _decodeUserData1(bytes32 userData)
        internal
        pure
        returns (
            address account,
            uint32 nonce,
            uint32 expiration,
            uint32 gasFeeLimit
        )
    {
        account = address(bytes20(userData));
        nonce = uint32(bytes4(userData << 160));
        expiration = uint32(bytes4(userData << 192));
        gasFeeLimit = uint32(bytes4(userData << 224));
    }

    function _decodeUserData2(bytes32 userData) internal pure returns (address to, uint32 gasFee) {
        to = address(bytes20(userData));
        gasFee = uint32(bytes4(userData << 160));
    }

    function _getGasFee(uint32 gasFee) internal pure returns (uint64) {
        return uint64(gasFee) * uint64(1e11);
    }
}
