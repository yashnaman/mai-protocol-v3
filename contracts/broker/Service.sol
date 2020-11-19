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

    struct OrderCache {
        bool success;
        bytes32 orderHash;
    }

    uint32 public constant SUPPORTED_MIN_ORDER_VERSION = 1;
    uint32 public constant SUPPORTED_MAX_ORDER_VERSION = 1;

    int256 internal constant MIN_PRICE = 0;
    int256 internal constant MAX_PRICE = type(int256).max;

    uint256 internal _chainID;
    mapping(bytes32 => int256) internal _filled;
    mapping(bytes32 => bool) internal _canceled;

    event TradeFailed(
        bytes32 orderHash,
        Order order,
        int256 amount,
        string message
    );
    event TradeSuccess(
        bytes32 orderHash,
        Order order,
        int256 amount,
        uint256 gasReward
    );

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
        uint256 orderCount = orders.length;
        OrderCache[] memory caches = new OrderCache[](orderCount);
        for (uint256 i = 0; i < orderCount; i++) {
            Order memory order = orders[i];
            bytes32 orderHash = OrderUtils.orderHash(order);
            (bool success, string memory reason) = _validateOrderFields(
                perpetual,
                order,
                orderHash,
                amounts[i],
                gasRewards[i]
            );
            if (!success) {
                if (actionOnFailure == ActionOnFailure.IGNORE) {
                    emit TradeFailed(orderHash, order, amounts[i], reason);
                } else if (actionOnFailure == ActionOnFailure.REVERT) {
                    revert(reason);
                }
            }
            caches[i] = OrderCache({orderHash: orderHash, success: success});
        }
        for (uint256 i = 0; i < orderCount; i++) {
            if (!caches[i].success) {
                continue;
            }
            Order memory order = orders[i];
            bool success = _execute(
                order,
                caches[i].orderHash,
                amounts[i],
                gasRewards[i]
            );
            if (!success) {
                if (actionOnFailure == ActionOnFailure.IGNORE) {
                    emit TradeFailed(
                        caches[i].orderHash,
                        order,
                        amounts[i],
                        "trading transaction failed"
                    );
                } else if (actionOnFailure == ActionOnFailure.REVERT) {
                    revert("trading transaction failed");
                }
            }
        }
    }

    function _execute(
        Order memory order,
        bytes32 orderHash,
        int256 amount,
        uint256 gasReward
    ) internal returns (bool success) {
        (success, ) = order.perpetual.call(
            abi.encodeWithSignature(
                "trade(address,int256,int256,uint256,address)",
                order.trader,
                amount,
                _priceLimit(order),
                order.deadline,
                order.referrer
            )
        );
        if (success) {
            if (gasReward > 0) {
                _transfer(order.trader, order.broker, gasReward);
            }
            emit TradeSuccess(orderHash, order, amount, gasReward);
        }
    }

    function _priceLimit(Order memory order) internal pure returns (int256) {
        if (order.orderType == OrderType.LIMIT) {
            return order.priceLimit;
        } else {
            return order.amount > 0 ? MAX_PRICE : MIN_PRICE;
        }
    }

    function _validateOrderFields(
        address perpetual,
        Order memory order,
        bytes32 orderHash,
        int256 amount,
        uint256 gasReward
    ) internal returns (bool, string memory) {
        if (
            order.version > SUPPORTED_MAX_ORDER_VERSION ||
            order.version < SUPPORTED_MIN_ORDER_VERSION
        ) {
            return (false, "unsupported order version");
        }

        if (gasReward > _balances[order.trader]) {
            return (false, "insufficient gas");
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
        if (order.broker != msg.sender) {
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
        if (order.closeOnly || order.orderType == OrderType.STOP) {
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
