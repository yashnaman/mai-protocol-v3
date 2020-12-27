// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

contract TestSignature {
    function hashMessage(bytes32 message) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(message));
    }

    function recoverMessage(bytes32 hash, bytes memory signature) public pure returns (address) {
        return ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(hash), signature);
    }

    function recoverMessage2(bytes32 hash, bytes memory signature) public pure returns (address) {
        return ECDSAUpgradeable.recover(hash, signature);
    }
}
