// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "../Type.sol";

import "hardhat/console.sol";

library OrderData {
    string internal constant DOMAIN_NAME = "Mai Protocol v3";
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        abi.encodePacked("EIP712Domain(string name)")
    );
    bytes32 internal constant DOMAIN_SEPARATOR = keccak256(
        abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME)))
    );
    bytes32 internal constant EIP712_ORDER_TYPE = keccak256(
        abi.encodePacked(
            "Order(address trader,address broker,address relayer,address referrer,address liquidityPool,uint256 perpetualIndex,int256 amount,int256 priceLimit,int256 minTradeAmount,uint256 tradeGasLimit,uint256 chainID,bytes32 data)"
        )
    );

    function deadline(Order memory order) internal pure returns (uint64) {
        return uint64(bytes8(order.data));
    }

    function orderType(Order memory order) internal pure returns (OrderType) {
        return OrderType(uint8(order.data[8]));
    }

    function isCloseOnly(Order memory order) internal pure returns (bool) {
        return uint8(order.data[9]) > 0;
    }

    function salt(Order memory order) internal pure returns (uint64) {
        return uint64(bytes8(order.data << (8 * 10)));
    }

    function orderHash(Order memory order) internal pure returns (bytes32) {
        bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result));
    }

    function signer(Order memory order, bytes memory signature) internal pure returns (address) {
        return
            ECDSAUpgradeable.recover(
                ECDSAUpgradeable.toEthSignedMessageHash(orderHash(order)),
                signature
            );
    }
}
