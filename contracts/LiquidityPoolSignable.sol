// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IPoolCreator.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";
import "./module/SignatureModule.sol";

import "./LiquidityPool.sol";
import "./Type.sol";

contract LiquidityPoolSignable is LiquidityPool {
    // function deposit(
    //     LiquidityPoolStorage storage liquidityPool,
    //     uint256 perpetualIndex,
    //     address trader,
    //     int256 amount,
    //     bytes32 extData,
    //     bytes calldata signature
    // ) public {
    //     require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
    //     address signer;
    //     if (extData != "" || signature.length != 0) {
    //         signer = SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
    //             extData,
    //             abi.encode(perpetualIndex, trader, amount),
    //             signature
    //         );
    //     } else {
    //         signer = msg.sender;
    //     }
    //     deposit(perpetualIndex, trader, amount);
    // }

    // function withdraw(
    //     LiquidityPoolStorage storage liquidityPool,
    //     uint256 perpetualIndex,
    //     address trader,
    //     int256 amount,
    //     bytes32 extData,
    //     bytes calldata signature
    // ) public {
    //     require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
    //     address signer;
    //     if (extData != "" || signature.length != 0) {
    //         signer = SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
    //             extData,
    //             abi.encode(perpetualIndex, trader, amount),
    //             signature
    //         );
    //     } else {
    //         signer = msg.sender;
    //     }
    //     require(
    //         isAuthorized(liquidityPool, trader, signer, Constant.PRIVILEGE_DEPOSTI),
    //         "unauthorized"
    //     );
    //     rebalance(liquidityPool, perpetualIndex);
    //     if (liquidityPool.perpetuals[perpetualIndex].withdraw(trader, amount)) {
    //         IPoolCreator(liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
    //     }
    //     liquidityPool.transferToUser(payable(trader), amount);
    // }

    // function settle(
    //     LiquidityPoolStorage storage liquidityPool,
    //     uint256 perpetualIndex,
    //     address trader,
    //     bytes32 extData,
    //     bytes calldata signature
    // ) public {
    //     require(trader != address(0), "trader is invalid");
    //     address signer;
    //     if (extData != "" || signature.length != 0) {
    //         signer = SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
    //             extData,
    //             abi.encode(perpetualIndex, trader),
    //             signature
    //         );
    //     } else {
    //         signer = msg.sender;
    //     }
    //     require(
    //         isAuthorized(liquidityPool, trader, signer, Constant.PRIVILEGE_DEPOSTI),
    //         "unauthorized"
    //     );
    //     int256 marginToReturn = liquidityPool.perpetuals[perpetualIndex].settle(trader);
    //     liquidityPool.transferToUser(payable(trader), marginToReturn);
    // }

    // function addLiquidity(
    //     LiquidityPoolStorage storage liquidityPool,
    //     address trader,
    //     int256 cashToAdd,
    //     bytes32 extData,
    //     bytes calldata signature
    // ) public {
    //     require(cashToAdd >= 0, "cash to add must be positive");
    //     address signer;
    //     if (extData != "" || signature.length != 0) {
    //         signer = SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
    //             extData,
    //             abi.encode(trader, cashToAdd),
    //             signature
    //         );
    //     } else {
    //         signer = msg.sender;
    //     }
    //     require(signer == trader, "unauthorized");
    //     int256 totalCashToAdd = liquidityPool.transferFromUser(trader, cashToAdd);
    //     IShareToken shareToken = IShareToken(liquidityPool.shareToken);
    //     int256 shareTotalSupply = shareToken.totalSupply().toInt256();
    //     int256 shareToMint = liquidityPool.getShareToMint(shareTotalSupply, totalCashToAdd);
    //     require(shareToMint > 0, "received share must be positive");
    //     shareToken.mint(trader, shareToMint.toUint256());
    //     liquidityPool.poolCash = liquidityPool.poolCash.add(totalCashToAdd);
    //     emit AddLiquidity(trader, totalCashToAdd, shareToMint);
    // }

    // function removeLiquidity(
    //     LiquidityPoolStorage storage liquidityPool,
    //     address trader,
    //     int256 shareToRemove,
    //     bytes32 extData,
    //     bytes calldata signature
    // ) public {
    //     require(shareToRemove >= 0, "share to remove must be positive");
    //     address signer =
    //         SignatureModule.EIP712_TYPED_REMOVE_LIQUIDITY.getSigner(
    //             extData,
    //             abi.encode(trader, shareToRemove),
    //             signature
    //         );
    //     require(trader == signer, "unauthorized signer");
    //     IShareToken shareToken = IShareToken(liquidityPool.shareToken);
    //     require(
    //         shareToRemove.toUint256() <= shareToken.balanceOf(trader),
    //         "insufficient share balance"
    //     );
    //     int256 shareTotalSupply = shareToken.totalSupply().toInt256();
    //     int256 cashToReturn = liquidityPool.getCashToReturn(shareTotalSupply, shareToRemove);
    //     require(cashToReturn >= 0, "cash to return is negative");
    //     require(cashToReturn <= getAvailablePoolCash(liquidityPool), "insufficient pool cash");
    //     shareToken.burn(trader, shareToRemove.toUint256());
    //     liquidityPool.transferToUser(payable(trader), cashToReturn);
    //     decreasePoolCash(liquidityPool, cashToReturn);
    //     emit RemoveLiquidity(trader, cashToReturn, shareToRemove);
    // }

    bytes[50] private __gap;
}
