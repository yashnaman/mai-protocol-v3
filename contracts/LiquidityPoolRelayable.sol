// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "./LiquidityPool.sol";

contract LiquidityPoolRelayable is LiquidityPool {
    // new domain, with version and chainId
    string public constant L2_DOMAIN_NAME = "Mai L2 Call";
    string public constant L2_DOMAIN_VERSION = "v3.0";
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

    function _msgSender() internal view virtual override returns (address payable) {
        if (msg.sender != address(this)) {
            return msg.sender;
        }
        return _getRelayedSigner();
    }

    function _getRelayedSigner() private pure returns (address payable signer) {
        require(msg.data.length >= 20, "invalid data format");
        uint256 tmp;
        assembly {
            tmp := calldataload(sub(calldatasize(), 32))
        }
        signer = address(bytes20(uint160(tmp)));
    }

    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasLimit,
        bytes memory signature
    ) public {
        require(expiration >= block.timestamp, "call expired");
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
            address(this).delegatecall(
                abi.encodePacked(bytes4(keccak256(bytes(method))), callData, signer)
            );
        require(success, "call function failed");
    }

    bytes[50] private __gap;
}
