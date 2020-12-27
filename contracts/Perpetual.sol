// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./libraries/Constant.sol";
import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";

import "./module/AMMModule.sol";
import "./module/MarginAccountModule.sol";
import "./module/TradeModule.sol";
import "./module/OrderModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./Storage.sol";
import "./Type.sol";

import "hardhat/console.sol";

contract Perpetual is Storage, Events, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using OrderData for Order;

    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;

    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using OrderModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;

    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (int256 cash, int256 position)
    {
        MarginAccount storage account = _liquidityPool.perpetuals[perpetualIndex]
            .marginAccounts[trader];
        cash = account.cash;
        position = account.position;
    }

    function getClearProgress(uint256 perpetualIndex)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (uint256 left, uint256 total)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        left = perpetual.activeAccounts.length();
        total = perpetual.clearedTraders.length().add(left);
    }

    function getSettleableMargin(uint256 perpetualIndex, address trader)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (int256 settleableMargin)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        int256 markPrice = perpetual.getMarkPrice();
        settleableMargin = perpetual.getSettleableMargin(trader, markPrice);
    }

    function donateInsuranceFund(uint256 perpetualIndex, int256 amount)
        external
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        onlyExistedPerpetual(perpetualIndex)
    {
        require(amount > 0, "amount is negative");
        int256 totalAmount = _liquidityPool.transferFromUser(msg.sender, amount);
        _liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(totalAmount);
    }

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    )
        external
        payable
        onlyAuthorized(trader, Constant.PRIVILEGE_DEPOSTI)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0 || msg.value > 0, "amount is invalid");

        int256 totalAmount = _liquidityPool.transferFromUser(trader, amount);
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        bool isJoining = perpetual.isEmptyAccount(trader);
        perpetual.deposit(trader, totalAmount);
        if (isJoining) {
            perpetual.registerActiveAccount(trader);
            IPoolCreator(_liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
    }

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        onlyNotPaused(perpetualIndex)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");

        _liquidityPool.transferToUser(payable(trader), amount);
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.rebalanceFrom(perpetual);
        perpetual.withdraw(trader, amount);
        if (perpetual.isEmptyAccount(trader)) {
            perpetual.deregisterActiveAccount(trader);
            IPoolCreator(_liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
    }

    function clear(uint256 perpetualIndex)
        public
        onlyWhen(perpetualIndex, PerpetualState.EMERGENCY)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        address dirtyAccount = perpetual.getNextDirtyAccount();
        perpetual.clear(dirtyAccount);

        if (perpetual.activeAccounts.length() == 0) {
            _liquidityPool.rebalanceFrom(perpetual);
            perpetual.settleCollateral();
            int256 marginToReturn = perpetual.settle(address(this));
            _liquidityPool.increasePoolCash(marginToReturn);
            perpetual.enterClearedState();
        }
    }

    function settle(uint256 perpetualIndex, address trader)
        public
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.CLEARED)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        int256 marginToReturn = _liquidityPool.perpetuals[perpetualIndex].settle(trader);
        _liquidityPool.transferToUser(payable(trader), marginToReturn);
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_TRADE)
        onlyNotPaused(perpetualIndex)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
    {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, isCloseOnly);
    }

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature,
        uint8 signType
    ) external syncState onlyWhen(order.perpetualIndex, PerpetualState.NORMAL) {
        _liquidityPool.validateSignature(order, signature, signType);
        _liquidityPool.validateOrder(order, amount);
        _liquidityPool.validateTriggerPrice(order);
        _liquidityPool.trade(
            order.perpetualIndex,
            order.trader,
            amount,
            order.limitPrice,
            order.referrer,
            order.isCloseOnly()
        );
    }

    function liquidateByAMM(
        uint256 perpetualIndex,
        address trader,
        uint256 deadline
    ) external syncState onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _liquidityPool.liquidateByAMM(perpetualIndex, trader);
    }

    function liquidateByTrader(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline
    ) external syncState onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _liquidityPool.liquidateByTrader(perpetualIndex, msg.sender, trader, amount, limitPrice);
    }

    bytes[50] private __gap;
}
