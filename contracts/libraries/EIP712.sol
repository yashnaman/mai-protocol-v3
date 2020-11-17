// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

library EIP712 {
    string internal constant DOMAIN_NAME = "Mai Protocol v3";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        abi.encodePacked("EIP712Domain(string name)")
    );

    bytes32 private constant DOMAIN_SEPARATOR = keccak256(
        abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME)))
    );

    /**
     * Calculates EIP712 encoding for a hash struct in this EIP712 Domain.
     *
     * @param eip712hash The EIP712 hash struct.
     * @return EIP712 hash applied to this EIP712 Domain.
     */
    function hashEIP712Message(bytes32 eip712hash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, eip712hash)
            );
    }
}
