// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

library OrderExt {
    bytes32 public constant EIP712_ORDER_TYPE = keccak256(
        abi.encodePacked(
            "Order(address trader,address broker,address perpetual,int256 amount,int256 price,uint64 deadline,uint32 version,OrderType orderType,bool closeOnly,uint64 salt,uint256 chainID)"
        )
    );

    function id(Order memory order) internal pure returns (bytes32 result) {
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
}
