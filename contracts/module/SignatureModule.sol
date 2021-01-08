// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../interface/IAccessControll.sol";

import "../libraries/Utils.sol";
import "../libraries/Signature.sol";

library SignatureModule {
    string internal constant DOMAIN_NAME = "Mai Protocol v3";
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked("EIP712Domain(string name)"));
    bytes32 internal constant DOMAIN_SEPARATOR =
        keccak256(abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME))));
    // trade
    bytes32 internal constant EIP712_TYPED_ORDER =
        keccak256(
            abi.encodePacked(
                "Order(address trader,address broker,address relayer,address referrer,address liquidityPool,",
                "int256 minTradeAmount,int256 amount,int256 limitPrice,int256 triggerPrice,uint256 chainID,",
                "uint64 expiredAt,uint32 perpetualIndex,uint32 brokerFeeLimit,uint32 flags,uint32 salt)"
            )
        );
    // deposit
    bytes32 internal constant EIP712_TYPED_DEPOSIT =
        keccak256(
            abi.encodePacked(
                "Deposit(address broker,address relayer,address liquidityPool,uint256 chainID,uint64 expiredAt,uint32 brokerFeeLimit,uint32 salt,",
                "uint32 perpetualIndex,address trader,int256 amount)"
            )
        );
    // withdraw
    bytes32 internal constant EIP712_TYPED_WITHDRAW =
        keccak256(
            abi.encodePacked(
                "Deposit(address broker,address relayer,address liquidityPool,uint32 brokerFeeLimit,uint64 expiredAt,uint256 chainID,uint32 salt,",
                "uint32 perpetualIndex,address trader,int256 amount)"
            )
        );
    // Settle
    bytes32 internal constant EIP712_TYPED_SETTLE =
        keccak256(abi.encodePacked("Settle(uint256 perpetualIndex,address trader)"));
    // Clear
    bytes32 internal constant EIP712_TYPED_CLEAR =
        keccak256(abi.encodePacked("Clear(uint256 perpetualIndex)"));
    // AddLiquidity
    bytes32 internal constant EIP712_TYPED_ADD_LIQUIDITY =
        keccak256(abi.encodePacked("AddLiquidity(address trader,int256 amount)"));
    // RemoveLiquidity
    bytes32 internal constant EIP712_TYPED_REMOVE_LIQUIDITY =
        keccak256(abi.encodePacked("RemoveLiquidity(address trader,int256 amount)"));
    // liquidateByAMM
    bytes32 internal constant EIP712_TYPED_LIQUIDATE_BY_AMM =
        keccak256(
            abi.encodePacked(
                "LiquidateByAMM(uint256 perpetualIndex,address trader,uint256 deadline)"
            )
        );
    // liquidityByTrader
    bytes32 internal constant EIP712_TYPED_LIQUIDITY_BY_TRADER =
        keccak256(
            abi.encodePacked(
                "LiquidateByTrader(uint256 perpetualIndex,address trader,int256 amount,int256 limitPrice,uint256 deadline)"
            )
        );

    // SetEmergencyState
    bytes32 internal constant EIP712_TYPED_SET_EMERGENCY_STATE =
        keccak256(abi.encodePacked("SetEmergencyState(uint256 perpetualIndex)"));

    function getDepositDigest(address trader, int256 amount) public pure returns (bytes32) {
        bytes32 result = keccak256(abi.encode(EIP712_TYPED_DEPOSIT, trader, amount));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result));
    }

    // address broker,address relayer,uint64 expiredAt,uint256 chainID,uint32 brokerFeeLimit,uint32 salt
    // address broker,address relayer,address liquidityPool,uint256 chainID,uint64 expiredAt,uint32 brokerFeeLimit,uint32 salt
    //
    // uint64 expiration,uint32 brokerFeeLimit,uint32 salt
    // address liquidityPool,uint32 perpetualIndex,address trader,int256 amount

    // uint64 expiredAt,uint32 brokerFeeLimit,uint32 salt
    // uint32 perpetualIndex,address trader,int256 amount

    // function validateSignature(
    //     LiquidityPoolStorage storage liquidityPool,
    //     bytes32 signedHash,
    //     bytes memory signature
    // ) public view {
    //     address signer = getSigner(signedHash, signature);
    // }

    /**
     * @notice Get signer of transaction
     * @param dataType The data type
     * @param extData The external data
     * @param args The arguments
     * @param signature The signature
     * @return signer The signer of transaction
     */
    function getSigner(
        bytes32 dataType, // EIP712_TYPED_DEPOSIT
        bytes32 extData, // uint64 expiredAt,uint32 brokerFeeLimit,uint32 salt
        bytes memory args, // abi.encode(xxxxx)
        bytes memory signature // signatures
    ) public view returns (address signer) {
        if (extData == "") {
            signer = msg.sender;
        } else {
            uint64 expiration = uint64(bytes8(extData));
            require(expiration >= block.timestamp, "ext data is expired");
            bytes32 signedHash =
                keccak256(
                    abi.encode(
                        dataType,
                        msg.sender,
                        tx.origin,
                        address(this),
                        Utils.chainID(),
                        expiration,
                        extData,
                        args
                    )
                );
            signedHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, signedHash));
            signer = Signature.getSigner(signedHash, signature);
        }
    }
}
