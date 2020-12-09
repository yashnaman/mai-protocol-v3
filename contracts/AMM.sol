// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./interface/IShareToken.sol";

import "./module/AMMModule.sol";
import "./module/CoreModule.sol";
import "./module/CollateralModule.sol";

import "./Type.sol";
import "./Storage.sol";
import "./Events.sol";

contract AMM is Storage, Events, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SignedSafeMathUpgradeable for int256;

    using AMMModule for Core;
    using CollateralModule for Core;
    using CoreModule for Core;

    function claimFee(int256 amount) external nonReentrant {
        _core.claimFee(msg.sender, amount);
    }

    function donateInsuranceFund(int256 amount) external payable nonReentrant {
        require(amount > 0, "amount is 0");
        _core.donateInsuranceFund(amount);
    }

    function addLiquidity(bytes32 marketID, int256 cashToAdd)
        external
        payable
        syncState
        nonReentrant
    {
        require(cashToAdd > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _core.transferFromUser(msg.sender, cashToAdd);
        int256 shareToMint = _core.addLiquidity(marketID, cashToAdd);
        IShareToken(_shareToken).mint(msg.sender, shareToMint.toUint256());

        emit AddLiquidity(msg.sender, cashToAdd, shareToMint);
    }

    function removeLiquidity(bytes32 marketID, int256 shareToRemove)
        external
        syncState
        nonReentrant
    {
        require(shareToRemove > 0, Error.INVALID_COLLATERAL_AMOUNT);
        int256 cashToReturn = _core.removeLiquidity(marketID, shareToRemove);
        IShareToken(_shareToken).burn(msg.sender, shareToRemove.toUint256());
        _core.transferToUser(payable(msg.sender), cashToReturn);

        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    bytes[50] private __gap;
}
