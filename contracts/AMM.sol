// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./interface/IShareToken.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/CollateralModule.sol";

import "./Type.sol";
import "./Storage.sol";

contract AMM is Storage, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SignedSafeMathUpgradeable for int256;

    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    function claimFee(int256 amount) external nonReentrant {
        _liquidityPool.claimFee(msg.sender, amount);
    }

    function donateInsuranceFund(int256 amount) external payable nonReentrant {
        require(amount > 0, "amount is 0");
        _liquidityPool.donateInsuranceFund(amount);
    }

    function addLiquidity(int256 cashToAdd) external payable syncState nonReentrant {
        require(cashToAdd > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.addLiquidity(cashToAdd);
    }

    function removeLiquidity(int256 shareToRemove) external syncState nonReentrant {
        require(shareToRemove > 0, "amount is invalid");
        _liquidityPool.removeLiquidity(shareToRemove);
    }

    bytes[50] private __gap;
}
