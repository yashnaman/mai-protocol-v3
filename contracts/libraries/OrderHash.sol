// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";

import "../Type.sol";

library OrderHash {
	string internal constant DOMAIN_NAME = "Mai Protocol v3";
	bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
		abi.encodePacked("EIP712Domain(string name)")
	);
	bytes32 internal constant DOMAIN_SEPARATOR = keccak256(
		abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME)))
	);
	bytes32 internal constant EIP712_ORDER_TYPE = keccak256(
		abi.encodePacked(
			"Order(address trader,address broker,address relayer,address perpetual,address referrer,int256 amount,int256 priceLimit,uint64 deadline,uint32 version,OrderType orderType,bool isCloseOnly,uint64 salt,uint256 chainID)"
		)
	);

	function orderHash(Order memory order) internal pure returns (bytes32) {
		bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
		return
			ECDSA.toEthSignedMessageHash(
				keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result))
			);
	}

	function orderHashDebug(Order memory order)
		internal
		pure
		returns (
			bytes32,
			bytes32,
			bytes32
		)
	{
		bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
		return (
			result,
			keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result)),
			ECDSA.toEthSignedMessageHash(
				keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result))
			)
		);
	}
}
