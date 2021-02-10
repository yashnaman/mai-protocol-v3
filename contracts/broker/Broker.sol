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
import "../interface/IRelayRecipient.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/OrderData.sol";
import "../libraries/Utils.sol";

import "../Type.sol";

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
     * @notice  Withdraw eth for gas reward.
     *
     * @param   amount  The amount of eth to withdraw.
     */
    function withdraw(uint256 amount) public nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        Address.sendValue(payable(msg.sender), amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Return if an order is canceled.
     *
     * @param   order   Order object.
     */
    function isOrderCanceled(Order memory order) public view returns (bool) {
        bytes32 orderHash = order.getOrderHash();
        return _orderCanceled[orderHash];
    }

    /**
     * @notice Return filled amount of an order.
     *
     * @param   order           Order object.
     * @return  filledAmount    The amount of already filled.
     */
    function getOrderFilledAmount(Order memory order) public view returns (int256 filledAmount) {
        bytes32 orderHash = order.getOrderHash();
        filledAmount = _orderFilled[orderHash];
    }

    /**
     * @notice  Get next avilable nonce for account. Nonce in an relayed call must match
     *          record on chain and will be increased on a successful call, to prevent replay attack.
     */
    function getNonce(address account) public view returns (uint32 nonce) {
        return _nonces[account];
    }

    /**
     * @notice  Cancel an order to prevent any further trade.
     *          Currently, Only trader or elayer and anthorized account (by order.trader)
     *          are able to cancel an order.
     *
     * @param   order   Order object.
     */
    function cancelOrder(Order memory order) public {
        if (msg.sender != order.trader && msg.sender != order.relayer) {
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

    /**
     * @notice  Making general function call to a contract who implements the IRelayRecipient interface.
     *          Relay (the one sends transaction for real signer) will get reward for successful relay call.
     *          The reward is desided by relayer but will not exceed gasFeeLimit set by user.
     *
     * @param   userData1   Compact bytes32 data, see `_decodeUserData1`.
     * @param   userData2   Compact bytes32 data, see `_decodeUserData2`.
     * @param   method      A string indicates the function to call, eg. 'deposit(uint256)'.
     * @param   callData    The calldata of method, using abi encode format.
     * @param   signature   The r-s-v combined format signature.
     */
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
        IRelayRecipient(to).callFunction(
            account,
            method,
            callData,
            nonce,
            expiration,
            _getGasFee(gasFeeLimit),
            signature
        );
        _nonces[account]++;
        if (gasFee > 0) {
            Address.sendValue(payable(msg.sender), _getGasFee(gasFee));
        }
        emit CallFunction(userData1, userData2, method, callData, signature);
    }

    /**
     * @notice  Trade multiple orders, each order will be treated seperately.
     * @param   compressedOrders    The compressed order objects to trade.
     * @param   amounts             The trading amounts of position.
     * @param   gasRewards          The gas rewards of eth given to their brokers.
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
     * @dev     Update the filled position amount of the order.
     *
     * @param   orderHash   The hash of the order.
     * @param   amount      The changed amount of filled position.
     */
    function _fillOrder(bytes32 orderHash, int256 amount) internal {
        _orderFilled[orderHash] = _orderFilled[orderHash].add(amount);
        emit FillOrder(orderHash, amount);
    }

    /**
     * @dev     Transfer eth from sender's account to recipient's account.
     *
     * @param   sender      The address of the sender
     * @param   recipient   The address of the recipient
     * @param   amount      The amount of eth to transfer
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

    /**
     * @dev     Decode compact userData, which contains:
     *            - A 20 bytes address, indicates the address of account to operate on;
     *            - A  4 bytes nonce, see `getNonce` for details;
     *            - A  4 bytes unix timestamp expiration;
     *            - A  4 bytes gasFeeLimit, multiply by 1e11 to get realy limit in 'wei';
     *          The gasFeeLimit is the max amount user wish to pay for the transaction.
     *
     * @param   userData    Compact userdata.
     */
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

    /**
     * @dev     Decode compact userData, which contains:
     *            - A 20 bytes address, indicates the final address of transaction to send to;
     *            - A  4 bytes gasFee, multiply by 1e11 to get realy fee in 'wei'.
     *          The gasFee is the actual fee claiming from pre-deposited funds by user, which should
     *          alway be lower than the gasFeeLimit.
     *
     * @param   userData    Compact userdata.
     */
    function _decodeUserData2(bytes32 userData) internal pure returns (address to, uint32 gasFee) {
        to = address(bytes20(userData));
        gasFee = uint32(bytes4(userData << 160));
    }

    /**
     * @dev     Convert gasFee in userData to wei.
     *
     * @param   gasFee  The amount from userData.
     */
    function _getGasFee(uint32 gasFee) internal pure returns (uint64) {
        return uint64(gasFee) * uint64(1e11);
    }
}
