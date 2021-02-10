// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IRelayRecipient {
    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasLimit,
        bytes memory signature
    ) external;
}
