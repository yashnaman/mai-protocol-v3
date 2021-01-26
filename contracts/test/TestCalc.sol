// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../libraries/OrderData.sol";
import "../libraries/Signature.sol";

import "hardhat/console.sol";

contract TestCalc is Ownable {
    using Address for address;

    uint256 public count;

    mapping(uint256 => mapping(address => int256)) internal _balances;

    bytes32 internal constant CALL_FUNCTION_TYPE =
        keccak256(
            abi.encodePacked(
                "Call(string method,address broker,address from,address to,bytes callData,uint32 nonce,uint32 expiration,uint64 gasLimit)"
            )
        );

    function add(uint256 value) public {
        require(count + value > count, "overflow");
        count = count + value;
    }

    function sub(uint256 value) public {
        require(value <= count, "underflow");
        count = count - value;
    }

    function balanceOf(uint256 perpetualIndex, address account) public view returns (int256) {
        return _balances[perpetualIndex][account];
    }

    function deposit(
        uint256 perpetualIndex,
        address account,
        int256 amount
    ) external {
        _balances[perpetualIndex][account] = _balances[perpetualIndex][account] + amount;
    }

    // function domainHash() public view returns (bytes32) {
    //     return OrderData.getDomainSeperator();
    // }

    // function messageData(
    //     address from,
    //     string memory functionSignature,
    //     bytes memory callData,
    //     uint32 nonce,
    //     uint32 expiration,
    //     uint64 gasFeeLimit
    // ) public view returns (bytes memory) {
    //     return
    //         abi.encode(
    //             CALL_FUNCTION_TYPE,
    //             keccak256(bytes(method)),
    //             msg.sender,
    //             from,
    //             address(this),
    //             keccak256(callData),
    //             nonce,
    //             expiration,
    //             gasFeeLimit
    //         );
    // }

    // function messageHash(
    //     address from,
    //     string memory functionSignature,
    //     bytes memory callData,
    //     uint32 nonce,
    //     uint32 expiration,
    //     uint64 gasFeeLimit
    // ) public view returns (bytes32) {
    //     return
    //         keccak256(
    //             abi.encode(
    //                 CALL_FUNCTION_TYPE,
    //                 keccak256(bytes(method)),
    //                 msg.sender,
    //                 from,
    //                 address(this),
    //                 keccak256(callData),
    //                 nonce,
    //                 expiration,
    //                 gasFeeLimit
    //             )
    //         );
    // }

    // function signedHash(
    //     address from,
    //     string memory functionSignature,
    //     bytes memory callData,
    //     uint32 nonce,
    //     uint32 expiration,
    //     uint64 gasFeeLimit
    // ) public view returns (bytes32) {
    //     bytes32 result =
    //         keccak256(
    //             abi.encode(
    //                 CALL_FUNCTION_TYPE,
    //                 keccak256(bytes(method)),
    //                 msg.sender,
    //                 from,
    //                 address(this),
    //                 keccak256(callData),
    //                 nonce,
    //                 expiration,
    //                 gasFeeLimit
    //             )
    //         );

    //     return keccak256(abi.encodePacked("\x19\x01", OrderData.getDomainSeperator(), result));
    // }

    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasFeeLimit,
        bytes memory signature
    ) public {
        require(expiration >= block.timestamp, "expired");
        bytes32 result =
            keccak256(
                abi.encode(
                    CALL_FUNCTION_TYPE,
                    keccak256(bytes(method)),
                    msg.sender,
                    from,
                    address(this),
                    keccak256(callData),
                    nonce,
                    expiration,
                    gasFeeLimit
                )
            );
        bytes32 signedHash =
            keccak256(abi.encodePacked("\x19\x01", OrderData.getDomainSeperator(), result));
        address signer = _getEIP712Signer(signedHash, signature);
        require(signer == from, "signer not match");
        (bool success, ) =
            address(this).delegatecall(
                abi.encodePacked(bytes4(keccak256(bytes(method))), callData)
            );
        require(success, "call failed");
    }

    function _getEIP712Signer(bytes32 signedHash, bytes memory signature)
        internal
        view
        returns (address signer)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "ECDSA: invalid signature 's' value"
        );
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");
        // signedHash = ECDSAUpgradeable.toEthSignedMessageHash(signedHash);
        signer = ecrecover(signedHash, v, r, s);
        require(signer != address(0), "invalid signature");
    }

    function _decodeUserData1(bytes32 userData)
        internal
        view
        returns (
            address account,
            uint32 nonce,
            uint32 expiration,
            uint32 gasFeeLimit
        )
    {
        account = address(bytes20(userData));
        nonce = uint32(bytes4(userData << 160));
        expiration = uint32(bytes4(userData << 192));
        gasFeeLimit = uint32(bytes4(userData << 224));
    }

    function _decodeUserData2(bytes32 userData) internal view returns (address to, uint32 gasFee) {
        to = address(bytes20(userData));
        gasFee = uint32(bytes4(userData << 160));
    }
}
