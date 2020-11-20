// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "./EIP712.sol";
import "./Utils.sol";
import "./SafeMathExt.sol";
import "./SignatureValidator.sol";

library OrderUtils {
    using SafeMathExt for int256;
    using SignatureValidator for Signature;

    bytes32 public constant EIP712_ORDER_TYPE = keccak256(
        abi.encodePacked(
            "Order(address trader,address broker,address perpetual,address referrer, int256 amount,int256 price,uint64 deadline,uint32 version,OrderType orderType,bool closeOnly,uint64 salt,uint256 chainID)"
        )
    );

    function orderHash(Order memory order)
        internal
        pure
        returns (bytes32 result)
    {
        return EIP712.hashEIP712Message(_orderHash(order));
    }

    function _orderHash(Order memory order)
        private
        pure
        returns (bytes32 result)
    {
        result = keccak256(
            abi.encodePacked(
                EIP712_ORDER_TYPE,
                order.trader,
                order.broker,
                order.perpetual,
                order.amount,
                order.priceLimit,
                order.deadline,
                order.version,
                order.orderType,
                order.closeOnly,
                order.salt,
                order.chainID
            )
        );
    }

    function validateOrderFields(
        Order memory order,
        MarginAccount storage account,
        int256 amount
    ) public view returns (bool, string memory) {
        if (order.trader != order.signature.getSigner(orderHash(order))) {
            return (false, "order signature mismatch");
        }
        if (order.amount == 0 || amount == 0) {
            return (false, "order fulfilled");
        }
        if (order.broker != msg.sender) {
            return (false, "broker mismatch");
        }
        if (order.chainID != Utils.chainID()) {
            return (false, "chainid mismatch");
        }
        if (order.deadline < block.timestamp) {
            return (false, "order expired");
        }
        if (order.closeOnly || order.orderType == OrderType.STOP) {
            if (Utils.hasSameSign(account.positionAmount, amount)) {
                return (false, "not close order");
            }
            if (amount.abs() > account.positionAmount.abs()) {
                return (false, "not close only");
            }
        }
        return (true, "");
    }
}
