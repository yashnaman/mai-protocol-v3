// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./libraries/Error.sol";
import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./interface/IFactory.sol";
import "./interface/IShareToken.sol";

import "./Type.sol";
import "./Storage.sol";
import "./module/AMMTradeModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/FeeModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./AccessControl.sol";

// import "hardhat/console.sol";

contract Trade is Storage, Events, AccessControl, ReentrancyGuard {
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMath for int256;
    using Address for address;

    using OrderData for Order;
    using OrderModule for Core;

    using AMMTradeModule for Core;
    using SettlementModule for Core;
    using TradeModule for Core;
    using FeeModule for Core;
    using MarginModule for Core;
    using CollateralModule for Core;
    using EnumerableSet for EnumerableSet.AddressSet;

    function claimFee(int256 amount) external nonReentrant {
        _core.claimFee(msg.sender, amount);
    }

    function deposit(address trader, int256 amount)
        external
        payable
        auth(trader, PRIVILEGE_DEPOSTI)
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        _core.transferFromUser(trader, amount, msg.value);
        _core.deposit(trader, amount.add(msg.value.toInt256()));
    }

    function withdraw(address trader, int256 amount)
        external
        syncState
        auth(trader, PRIVILEGE_WITHDRAW)
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        _core.withdraw(trader, amount);
        _core.transferToUser(payable(trader), amount);
    }

    function donateInsuranceFund(int256 amount)
        external
        payable
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        if (_core.isWrapped && msg.value > 0) {
            IWETH(IFactory(_core.factory).weth()).deposit();
        }
        _core.transferFromUser(msg.sender, amount, msg.value);
        _core.donatedInsuranceFund = _core.donatedInsuranceFund.add(amount);
        emit DonateInsuranceFund(msg.sender, amount);
    }

    function addLiquidity(int256 cashToAdd)
        external
        payable
        syncState
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        require(cashToAdd > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _core.transferFromUser(msg.sender, cashToAdd, msg.value);
        int256 shareTotalSupply = IShareToken(_shareToken).totalSupply().toInt256();
        int256 shareToMint = _core.addLiquidity(shareTotalSupply, cashToAdd);
        uint256 unitInsuranceFund = shareTotalSupply > 0
            ? _core.insuranceFund.wdiv(shareTotalSupply).toUint256()
            : 0;
        _core.updateCashBalance(address(this), cashToAdd);
        IShareToken(_shareToken).mint(msg.sender, shareToMint.toUint256(), unitInsuranceFund);

        emit AddLiquidity(msg.sender, cashToAdd, shareToMint);
    }

    function removeLiquidity(int256 shareToRemove)
        external
        syncState
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        require(shareToRemove > 0, Error.INVALID_COLLATERAL_AMOUNT);

        int256 shareTotalSupply = IShareToken(_shareToken).totalSupply().toInt256();
        int256 cashToReturn = _core.removeLiquidity(shareTotalSupply, shareToRemove);
        IShareToken(_shareToken).burn(msg.sender, shareToRemove.toUint256());
        _core.updateCashBalance(address(this), cashToReturn.neg());
        _core.transferToUser(payable(msg.sender), cashToReturn);

        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    function trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    ) external auth(trader, PRIVILEGE_TRADE) {
        _trade(trader, amount, priceLimit, deadline, referrer);
    }

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature
    ) external {
        // signer
        address signer = order.signer(signature);
        require(signer == order.trader || isGranted(order.trader, signer, PRIVILEGE_TRADE), "");
        // validate
        _core.validateOrder(order, amount);
        // do trade
        _trade(order.trader, amount, order.priceLimit, order.deadline(), order.referrer);
    }

    function liquidateByAMM(address trader, uint256 deadline)
        external
        syncState
        onlyWhen(State.NORMAL)
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
        require(!_core.isMaintenanceMarginSafe(trader), "trader is safe");

        Receipt memory receipt = _core.liquidateByAMM(trader);
        _core.transferToUser(msg.sender, _core.keeperGasReward);
        if (_core.donatedInsuranceFund < 0) {
            _enterEmergencyState();
        }
        emit LiquidateByAMM(
            trader,
            receipt.tradingAmount,
            receipt.tradingValue.wdiv(receipt.tradingAmount).abs(),
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee),
            deadline
        );
    }

    function liquidateByTrader(
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline
    ) external syncState onlyWhen(State.NORMAL) nonReentrant {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
        require(!_core.isMaintenanceMarginSafe(trader), "trader is safe");

        Receipt memory receipt = _core.liquidateByTrader(msg.sender, trader, amount, priceLimit);
        if (_core.donatedInsuranceFund < 0) {
            _enterEmergencyState();
        }
        // 4.send penalty to margin of keeper
        _core.transferToUser(msg.sender, _core.keeperGasReward);
        emit LiquidateByTrader(
            msg.sender,
            trader,
            receipt.tradingAmount,
            receipt.tradingValue.wdiv(receipt.tradingAmount).abs(),
            deadline
        );
    }

    function _trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    ) internal syncState onlyWhen(State.NORMAL) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount != 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
        Receipt memory receipt = _core.trade(trader, amount, priceLimit, referrer);
        emit Trade(
            trader,
            receipt.tradingAmount,
            receipt.tradingValue.wdiv(receipt.tradingAmount).abs(),
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(receipt.referrerFee),
            deadline
        );
    }

    bytes[50] private __gap;
}
