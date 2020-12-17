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
            "Order(address trader,address broker,address relayer,address referrer,address liquidityPool,",
            "int256 minTradeAmount,int256 amount,int256 limitPrice,int256 triggerPrice,uint256 chainID,",
            "uint64 expiredAt,uint32 perpetualIndex,uint32 brokerFeeLimit,uint32 flags,uint32 salt)"
        )
    );

    uint32 internal constant MASK_CLOSE_ONLY = 0x80000000;
    uint32 internal constant MASK_MARKET_ORDER = 0x40000000;
    uint32 internal constant MASK_STOP_LOSS_ORDER = 0x20000000;
    uint32 internal constant MASK_TAKE_PROFIT_ORDER = 0x10000000;

    function isCloseOnly(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_CLOSE_ONLY) > 0;
    }

    function isMarketOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_MARKET_ORDER) > 0;
    }

    function isStopLossOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_STOP_LOSS_ORDER) > 0;
    }

    function isTakeProfitOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_TAKE_PROFIT_ORDER) > 0;
    }

    function orderHash(Order memory order) internal pure returns (bytes32) {
        bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result));
    }

    function signer(
        Order memory order,
        bytes memory signature,
        bool isEIP712
    ) internal pure returns (address signerAddress) {
        bytes32 hash = orderHash(order);
        if (!isEIP712) {
            hash = ECDSAUpgradeable.toEthSignedMessageHash(hash);
        }
        return ECDSAUpgradeable.recover(hash, signature);
    }
}
