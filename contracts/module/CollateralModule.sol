// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/Constant.sol";

import "../interface/IDecimals.sol";
import "../interface/IPoolCreator.sol";
import "../interface/IWETH.sol";

import "../Type.sol";

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

    uint256 internal constant SYSTEM_DECIMALS = 18;

    function initializeCollateral(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        uint256 collateralDecimals
    ) public {
        require(collateralDecimals <= SYSTEM_DECIMALS, "collateral decimals is out of range");
        try IDecimals(collateral).decimals() returns (uint8 decimals) {
            require(decimals == collateralDecimals, "decimals not match");
        } catch {}
        uint256 factor = 10**(SYSTEM_DECIMALS.sub(collateralDecimals));
        liquidityPool.scaler = (factor == 0 ? 1 : factor);
        liquidityPool.collateralToken = collateral;
        liquidityPool.collateralDecimals = collateralDecimals;
    }

    function transferFromUser(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public returns (int256 totalAmount) {
        if (!liquidityPool.isWrapped) {
            require(msg.value == 0, "native currency is not acceptable");
        }
        if (liquidityPool.isWrapped && msg.value > 0) {
            int256 internalAmount = _toInternalAmount(liquidityPool, msg.value);
            IWETH weth = IWETH(IPoolCreator(liquidityPool.creator).weth());
            uint256 currentBalance = weth.balanceOf(address(this));
            weth.deposit{ value: msg.value }();
            require(
                weth.balanceOf(address(this)).sub(currentBalance) == msg.value,
                "fail to deposit weth"
            );
            totalAmount = totalAmount.add(internalAmount);
        }
        if (amount > 0) {
            uint256 rawAmount = _toRawAmount(liquidityPool, amount);
            IERC20Upgradeable(liquidityPool.collateralToken).safeTransferFrom(
                account,
                address(this),
                rawAmount
            );
            totalAmount = totalAmount.add(amount);
        }
    }

    function transferToUser(
        LiquidityPoolStorage storage liquidityPool,
        address payable account,
        int256 amount
    ) public {
        uint256 rawAmount = _toRawAmount(liquidityPool, amount);
        if (liquidityPool.isWrapped) {
            IWETH weth = IWETH(IPoolCreator(liquidityPool.creator).weth());
            weth.withdraw(rawAmount);
            AddressUpgradeable.sendValue(account, rawAmount);
        } else {
            IERC20Upgradeable(liquidityPool.collateralToken).safeTransfer(account, rawAmount);
        }
    }

    function _toInternalAmount(LiquidityPoolStorage storage liquidityPool, uint256 amount)
        private
        view
        returns (int256 internalAmount)
    {
        internalAmount = amount.mul(liquidityPool.scaler).toInt256();
    }

    function _toRawAmount(LiquidityPoolStorage storage liquidityPool, int256 amount)
        private
        view
        returns (uint256 rawAmount)
    {
        rawAmount = amount.toUint256().div(liquidityPool.scaler);
    }
}
