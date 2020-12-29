// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "../Type.sol";

import "hardhat/console.sol";

library OrderData {
    string internal constant DOMAIN_NAME = "Mai Protocol v3";
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked("EIP712Domain(string name)"));
    bytes32 internal constant DOMAIN_SEPARATOR =
        keccak256(abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME))));
    bytes32 internal constant EIP712_ORDER_TYPE =
        keccak256(
            abi.encodePacked(
                "Order(address trader,address broker,address relayer,address referrer,address liquidityPool,",
                "int256 minTradeAmount,int256 amount,int256 limitPrice,int256 triggerPrice,uint256 chainID,",
                "uint64 expiredAt,uint32 perpetualIndex,uint32 brokerFeeLimit,uint32 flags,uint32 salt)"
            )
        );

    uint8 internal constant SIGN_TYPE_ETH = 0x0;
    uint8 internal constant SIGN_TYPE_EIP712 = 0x0;

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

    function isCloseOnly(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_CLOSE_ONLY) > 0;
    }

    function isMarketOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_MARKET_ORDER) > 0;
    }

    function isStopLossOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_STOP_LOSS_ORDER) > 0;
    }

    function isTakeProfitOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_TAKE_PROFIT_ORDER) > 0;
    }

    function getSigner(Order memory order, bytes memory signature)
        internal
        pure
        returns (address signerAddress)
    {
        uint8 signType;
        assembly {
            signType := byte(1, mload(add(signature, 0x60)))
        }
        bytes32 hash = getOrderHash(order);
        if (signType == SIGN_TYPE_ETH) {
            hash = ECDSAUpgradeable.toEthSignedMessageHash(hash);
        } else if (signType != SIGN_TYPE_EIP712) {
            revert("unsupported sign type");
        }
        return ECDSAUpgradeable.recover(hash, signature);
    }

    function getOrderHash(Order memory order) internal pure returns (bytes32) {
        bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result));
    }

    function decodeSignature(bytes memory orderData)
        internal
        pure
        returns (bytes memory signature)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 signType;
        assembly {
            r := mload(add(orderData, 318))
            s := mload(add(orderData, 350))
            v := byte(24, mload(add(orderData, 292)))
            signType := byte(25, mload(add(orderData, 292)))
        }
        signature = abi.encodePacked(r, s, v, signType);
    }

    function decodeOrderData(bytes memory data) internal pure returns (Order memory order) {
        bytes32 tmp;
        assembly {
            // trader / 20
            mstore(add(order, 0), mload(add(data, 20)))
            // broker / 20
            mstore(add(order, 32), mload(add(data, 40)))
            // relayer / 20
            mstore(add(order, 64), mload(add(data, 60)))
            // referrer / 20
            mstore(add(order, 96), mload(add(data, 80)))
            // liquidityPool / 20
            mstore(add(order, 128), mload(add(data, 100)))
            // minTradeAmount / 20
            mstore(add(order, 160), mload(add(data, 132)))
            // amount / 32
            mstore(add(order, 192), mload(add(data, 164)))
            // limitPrice / 32
            mstore(add(order, 224), mload(add(data, 196)))
            // triggerPrice / 32
            mstore(add(order, 256), mload(add(data, 228)))
            // chainID / 32
            mstore(add(order, 288), mload(add(data, 260)))
            // expiredAt + perpetualIndex + brokerFeeLimit + flags + salt + v + signType / 26
            tmp := mload(add(data, 292))
        }
        order.expiredAt = uint64(bytes8(tmp));
        order.perpetualIndex = uint32(bytes4(tmp << 64));
        order.brokerFeeLimit = uint32(bytes4(tmp << 96));
        order.flags = uint32(bytes4(tmp << 128));
        order.salt = uint32(bytes4(tmp << 160));
    }
}
