// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./libraries/Error.sol";
import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./interface/IFactory.sol";
import "./interface/IShareToken.sol";

import "./Type.sol";
import "./Storage.sol";
import "./module/AMMModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/FeeModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./AccessControl.sol";

// import "hardhat/console.sol";

contract Trade is Storage, Events, AccessControl, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;

    using OrderData for Order;
    using OrderModule for Core;

    using FeeModule for Core;
    using AMMModule for Core;
    using SettlementModule for Core;
    using TradeModule for Core;
    using MarginModule for Core;
    using CollateralModule for Core;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    function claimFee(int256 amount) external nonReentrant {
        _core.claimFee(msg.sender, amount);
    }

    function deposit(
        bytes32 marketID,
        address trader,
        int256 amount
    )
        external
        payable
        auth(trader, PRIVILEGE_DEPOSTI)
        onlyWhen(marketID, MarketState.NORMAL)
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _core.transferFromUser(trader, amount, msg.value);
        _core.deposit(marketID, trader, amount.add(msg.value.toInt256()));
    }

    function withdraw(
        bytes32 marketID,
        address trader,
        int256 amount
    )
        external
        syncState
        auth(trader, PRIVILEGE_WITHDRAW)
        onlyWhen(marketID, MarketState.NORMAL)
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _core.withdraw(marketID, trader, amount);
        _core.transferToUser(payable(trader), amount);
    }

    function donateInsuranceFund(int256 amount) external payable nonReentrant {
        require(amount > 0, "amount is 0");
        _core.transferFromUser(msg.sender, amount, msg.value);
        _core.donatedInsuranceFund = _core.donatedInsuranceFund.add(amount);
        emit DonateInsuranceFund(msg.sender, amount);
    }

    function addLiquidity(bytes32 marketID, int256 cashToAdd)
        external
        payable
        syncState
        nonReentrant
    {
        require(cashToAdd > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _core.transferFromUser(msg.sender, cashToAdd, msg.value);
        int256 shareToMint = _core.addLiquidity(marketID, cashToAdd);
        // _core.updateCashBalance(address(this), cashToAdd);
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
        // _core.updateCashBalance(address(this), cashToReturn.neg());
        _core.transferToUser(payable(msg.sender), cashToReturn);

        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    function trade(
        bytes32 marketID,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    ) external syncState auth(trader, PRIVILEGE_TRADE) onlyWhen(marketID, MarketState.NORMAL) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
        _core.trade(marketID, trader, amount, priceLimit, referrer);
    }

    function brokerTrade(
        Order memory order,
        bytes32 marketID,
        int256 amount,
        bytes memory signature
    ) external {
        // signer
        address signer = order.signer(signature);
        require(signer == order.trader || isGranted(order.trader, signer, PRIVILEGE_TRADE), "");
        // validate
        _core.validateOrder(order, amount);
        // do trade
        _core.trade(marketID, order.trader, amount, order.priceLimit, order.referrer);
    }

    function liquidateByAMM(
        bytes32 marketID,
        address trader,
        uint256 deadline
    ) external syncState onlyWhen(marketID, MarketState.NORMAL) nonReentrant {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);

        int256 keeperReward = _core.liquidateByAMM(marketID, trader);
        _core.transferToUser(msg.sender, keeperReward);
        if (_core.donatedInsuranceFund < 0) {
            _enterEmergencyState(marketID);
        }
    }

    function liquidateByTrader(
        bytes32 marketID,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline
    ) external syncState onlyWhen(marketID, MarketState.NORMAL) nonReentrant {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);

        _core.liquidateByTrader(marketID, msg.sender, trader, amount, priceLimit);
        if (_core.donatedInsuranceFund < 0) {
            _enterEmergencyState(marketID);
        }
    }

    bytes[50] private __gap;
}
