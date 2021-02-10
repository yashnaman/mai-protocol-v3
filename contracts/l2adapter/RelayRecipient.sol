// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "../libraries/Utils.sol";

/**
 * @notice This is a module adding relayed function call to contract.
 */
contract RelayRecipient is ContextUpgradeable {
    // new domain, with version and chainId
    string internal constant L2_DOMAIN_NAME = "Mai L2 Call";
    string internal constant L2_DOMAIN_VERSION = "v3.0";
    bytes32 internal constant L2_EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version)");
    bytes32 internal constant L2_DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                L2_EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(L2_DOMAIN_NAME)),
                keccak256(bytes(L2_DOMAIN_VERSION))
            )
        );
    bytes32 internal constant CALL_FUNCTION_TYPEHASH =
        keccak256(
            "Call(uint256 chainId,string method,address broker,address from,address to,bytes callData,uint32 nonce,uint32 expiration,uint64 gasLimit)"
        );

    /**
     * @notice Call function from broker.
     */
    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasLimit,
        bytes memory signature
    ) public {
        require(expiration >= block.timestamp, "relay call expired");
        bytes32 structHash =
            keccak256(
                abi.encode(
                    CALL_FUNCTION_TYPEHASH,
                    Utils.chainID(),
                    keccak256(bytes(method)),
                    msg.sender,
                    from,
                    address(this),
                    keccak256(callData),
                    nonce,
                    expiration,
                    gasLimit
                )
            );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", L2_DOMAIN_SEPARATOR, structHash));
        address signer = ECDSAUpgradeable.recover(digest, signature);
        require(signer == from, "signer mismatch");
        (bool success, ) =
            address(this).call(
                abi.encodePacked(bytes4(keccak256(bytes(method))), callData, signer)
            );
        require(success, "call function failed");
    }

    /**
     * @dev     A key feature to replace msg.sender with what is ecoded at the tail of msg.data.
     *          inspired by openzeppelin GSN network.
     */
    function _msgSender() internal view virtual override returns (address payable) {
        if (msg.sender != address(this)) {
            return msg.sender;
        }
        return _getRelayedCallSender();
    }

    function _getRelayedCallSender() private view returns (address payable sender) {
        require(msg.data.length >= 20, "invalid data format");
        uint256 tmp;
        assembly {
            tmp := calldataload(sub(calldatasize(), 32))
        }
        sender = address(bytes20(uint160(tmp)));
    }

    bytes32[50] private __gap;
}
