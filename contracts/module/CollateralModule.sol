// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../interface/IFactory.sol";
import "../interface/IWETH.sol";

import "../Type.sol";

import "hardhat/console.sol";

/**
 * @title   Collateral Module
 * @dev     Handle underlying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlying collateral
 *
 */
library CollateralModule {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev     Get collateral balance in account.
     * @param   account     Address of account.
     * @return  Raw repesentation of collateral balance.
     */
    function collateralBalance(LiquidityPoolStorage storage liquidityPool, address account)
        internal
        view
        returns (int256)
    {
        return IERC20Upgradeable(liquidityPool.collateral).balanceOf(account).toInt256();
    }

    /**
     * @dev     Transfer token from user if token is erc20 token.
     * @param   account     Address of account owner.
     * @param   amount   Amount of token to be transferred into contract.
     */
    function transferFromUser(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public returns (int256 totalAmount) {
        require(msg.value == 0 || liquidityPool.isWrapped, "native collateral is not acceptable");
        if (liquidityPool.isWrapped && msg.value > 0) {
            int256 internalAmount = _toInternalAmount(liquidityPool, msg.value).toInt256();
            IWETH(IFactory(liquidityPool.factory).weth()){ value: msg.value }.deposit();
            totalAmount = totalAmount.add(internalAmount);
        }
        if (amount > 0) {
            uint256 rawAmount = _toRawAmount(liquidityPool, amount.toUint256());
            IERC20Upgradeable(liquidityPool.collateral).safeTransferFrom(
                account,
                address(this),
                rawAmount
            );
            totalAmount = totalAmount.add(amount);
        }
    }

    /**
     * @dev     Transfer token to user no matter erc20 token or ether.
     * @param   account     Address of account owner.
     * @param   amount   Amount of token to be transferred to user.
     */
    function transferToUser(
        LiquidityPoolStorage storage liquidityPool,
        address payable account,
        int256 amount
    ) public {
        uint256 rawAmount = _toRawAmount(liquidityPool, amount.toUint256());
        if (liquidityPool.isWrapped) {
            IWETH(IFactory(liquidityPool.factory).weth()).withdraw(rawAmount);
            AddressUpgradeable.sendValue(account, rawAmount);
        } else {
            IERC20Upgradeable(liquidityPool.collateral).safeTransfer(account, rawAmount);
        }
    }

    /**
     * @dev     Convert the represention of amount from internal to raw.
     * @param   amount  Amount with internal decimals.
     * @return  Amount  with decimals of token.
     */
    function _toInternalAmount(LiquidityPoolStorage storage liquidityPool, uint256 amount)
        private
        view
        returns (uint256)
    {
        return amount.mul(liquidityPool.scaler);
    }

    /**
     * @dev     Convert the represention of amount from internal to raw.
     * @param   amount  Amount with internal decimals.
     * @return  Amount  with decimals of token.
     */
    function _toRawAmount(LiquidityPoolStorage storage liquidityPool, uint256 amount)
        private
        view
        returns (uint256)
    {
        return amount.div(liquidityPool.scaler);
    }
}
