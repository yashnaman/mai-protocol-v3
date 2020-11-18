// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/OrderUtils.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/SignatureValidator.sol";
import "../libraries/Utils.sol";
import "../Type.sol";
import "./Fee.sol";

interface IPerpetual {
    function marginAccount(address trader)
        external
        returns (
            int256 margin,
            int256 positionAmount,
            int256 availableMargin
        );
}

contract Service is Fee {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using OrderUtils for Order;
    using SignatureValidator for Signature;

    uint32 public constant SUPPORTED_MIN_ORDER_VERSION = 1;
    uint32 public constant SUPPORTED_MAX_ORDER_VERSION = 1;

    uint256 internal _chainID;
    mapping(bytes32 => int256) internal _filled;
    mapping(bytes32 => bool) internal _canceled;

    event TradeFailed(Order order, int256 amount, string message);
    event TradeSuccess(Order order, int256 amount, uint256 gasReward);

    // constructor() {
    //     _chainID = Utils.chainID();
    // }

    function batchTrade(
        address perpetual,
        Order[] calldata orders,
        int256[] calldata amounts,
        uint256[] calldata gasRewards,
        ActionOnFailure actionOnFailure
    ) external {
        uint256 numOrders = orders.length;
        for (uint256 i = 0; i < numOrders; i++) {
            Order memory order = orders[i];
            int256 amount = amounts[i];
            uint256 gasReward = gasRewards[i];

            (bool valid, string memory reason) = _validateOrderFields(
                perpetual,
                order,
                amount
            );
            if (!valid) {
                if (actionOnFailure == ActionOnFailure.IGNORE) {
                    continue;
                } else {
                    revert(reason);
                }
            }
            (bool success, ) = perpetual.call(
                abi.encodeWithSignature(
                    "trade(address,int256,int256,uint256,address)",
                    order.trader,
                    amount,
                    order.priceLimit,
                    order.deadline,
                    order.referrer
                )
            );
            if (success) {
                emit TradeSuccess(order, amount, gasReward);
                if (gasReward > 0) {
                    _transfer(order.trader, order.broker, gasReward);
                }
            } else if (actionOnFailure == ActionOnFailure.IGNORE) {
                emit TradeFailed(order, amount, "trade failed");
            } else if (actionOnFailure == ActionOnFailure.REVERT) {
                revert("trade failed");
            }
        }
    }

    function _validateOrderFields(
        address perpetual,
        Order memory order,
        int256 amount
    ) internal returns (bool, string memory) {
        bytes32 orderHash = order.orderHash();
        if (
            order.version > SUPPORTED_MAX_ORDER_VERSION ||
            order.version < SUPPORTED_MIN_ORDER_VERSION
        ) {
            return (false, "unsupported order version");
        }
        if (order.trader != order.signature.getSigner(orderHash)) {
            return (false, "order signature mismatch");
        }
        if (order.amount == 0 || amount == 0) {
            return (false, "order fulfilled");
        }
        if (_canceled[orderHash]) {
            return (false, "order canceled");
        }
        if (amount > order.amount.sub(_filled[orderHash])) {
            return (false, "exceed order fillable amount");
        }
        if (order.broker != address(this)) {
            return (false, "broker mismatch");
        }
        if (order.perpetual != perpetual) {
            return (false, "perpetual mismatch");
        }
        if (order.chainID != _chainID) {
            return (false, "chainid mismatch");
        }
        if (order.deadline < block.timestamp) {
            return (false, "order expired");
        }
        if (order.closeOnly) {
            (, int256 positionAmount, ) = IPerpetual(perpetual).marginAccount(
                order.trader
            );
            if (Utils.hasSameSign(positionAmount, amount)) {
                return (false, "not close order");
            }
            if (amount.abs() > positionAmount.abs()) {
                return (false, "not close only");
            }
        }
        return (true, "");
    }
}
