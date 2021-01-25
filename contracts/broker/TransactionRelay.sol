// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";

contract TransactionRelay {
    using Address for address;

    mapping(address => uint32) internal _nonces;

    event CallFunction(
        address indexed to,
        string functionSignature,
        bytes callData,
        bytes32 userData,
        uint32 gasFeeLimit,
        bytes signature
    );

    function getNonces(address account) public view returns (uint32 nonce) {
        return _nonces[account];
    }

    function callFunction(
        address to,
        string memory functionSignature,
        bytes memory callData,
        bytes32 userData,
        uint32 gasFee,
        bytes memory signature
    ) public {
        address account;
        {
            uint64 nonce;
            uint64 expiration;
            uint64 gasFeeLimit;
            (account, nonce, expiration, gasFeeLimit) = _decodeUserData(userData);
            require(nonce == _nonces[account] + 1, "non-continuous nonce");
            require(expiration >= block.timestamp, "expired");
            require(gasFee <= gasFeeLimit, "fee exceeds limit");
        }
        (bool success, ) = to.call(callData);
        require(success, "transaction reverted");
        Address.sendValue(payable(account), gasFee);
        _nonces[account]++;
        emit CallFunction(to, functionSignature, callData, userData, gasFee, signature);
    }

    function _getGasFee(uint32 gasFee) internal view returns (uint256) {
        return gasFee * 1e11;
    }

    function _decodeUserData(bytes32 userData)
        internal
        view
        returns (
            address account,
            uint64 nonce,
            uint64 expiration,
            uint64 gasFeeLimit
        )
    {
        bytes32 tmp;
        assembly {
            account := mload(add(userData, 20))
            nonce := mload(add(userData, 44))
            expiration := mload(add(userData, 48))
            gasFeeLimit := mload(add(userData, 52))
        }
    }
}
