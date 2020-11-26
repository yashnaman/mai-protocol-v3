// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
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
import "./module/SettleModule.sol";
import "./module/StateModule.sol";
import "./module/OrderModule.sol";
import "./module/FeeModule.sol";

import "./Events.sol";
import "./AccessControl.sol";
import "./Collateral.sol";

// import "hardhat/console.sol";

contract Operation is Storage, Events, AccessControl, Collateral, ReentrancyGuard {
	using SafeCast for int256;
	using SafeCast for uint256;
	using SafeMath for uint256;
	using SafeMathExt for int256;
	using SafeMathExt for uint256;
	using SignedSafeMath for int256;

	using OrderData for Order;
	using OrderModule for Core;

	using AMMTradeModule for Core;
	using SettleModule for Core;
	using TradeModule for Core;
	using FeeModule for Core;
	using StateModule for Core;
	using MarginModule for Core;
	using EnumerableSet for EnumerableSet.AddressSet;

	modifier userTrace(address trader) {
		int256 preAmount = _core.marginAccounts[trader].positionAmount;
		_;
		int256 postAmount = _core.marginAccounts[trader].positionAmount;
		if (preAmount == 0 && postAmount != 0) {
			_core.registerTrader(trader);
			// IFactory(_core.factory).activeProxy(trader);
		} else if (preAmount != 0 && postAmount == 0) {
			_core.deregisterTrader(trader);
			// IFactory(_core.factory).deactiveProxy(trader);
		}
	}

	function marginAccount(address trader)
		public
		view
		returns (
			int256 positionAmount,
			int256 cashBalance,
			int256 entryFundingLoss
		)
	{
		positionAmount = _core.marginAccounts[trader].positionAmount;
		cashBalance = _core.marginAccounts[trader].cashBalance;
		entryFundingLoss = _core.marginAccounts[trader].entryFundingLoss;
	}

	function margin(address trader) public syncState returns (int256) {
		return _core.margin(trader);
	}

	function availableMargin(address trader) public syncState returns (int256) {
		return _core.availableMargin(trader);
	}

	function withdrawableMargin(address trader) public syncState returns (int256 withdrawable) {
		if (_core.isNormal()) {
			withdrawable = _core.availableMargin(trader);
		} else {
			withdrawable = _core.withdrawableMargin(trader);
		}
		return withdrawable > 0 ? withdrawable : 0;
	}

	function claimableFee(address claimer) public view returns (int256) {
		return _core.claimableFee[claimer];
	}

	function claimFee(address claimer, int256 amount) external nonReentrant {
		require(amount != 0, "zero amount");
		_core.claimFee(claimer, amount);
		_transferToUser(payable(claimer), amount);
		emit ClaimFee(claimer, amount);
	}

	function deposit(address trader, int256 amount)
		external
		auth(trader, PRIVILEGE_DEPOSTI)
		nonReentrant
	{
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
		require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
		_transferFromUser(trader, amount);
		_core.updateCashBalance(trader, amount);
		emit Withdraw(trader, amount);
	}

	function donateInsuranceFund(int256 amount) external nonReentrant {
		require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
		_transferFromUser(msg.sender, amount);
		_core.donatedInsuranceFund = _core.donatedInsuranceFund.add(amount);
		emit DonateInsuranceFund(msg.sender, amount);
	}

	function withdraw(address trader, int256 amount)
		external
		syncState
		auth(trader, PRIVILEGE_WITHDRAW)
		nonReentrant
	{
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
		require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
		_core.updateCashBalance(trader, amount.neg());
		_core.isInitialMarginSafe(trader);
		_transferFromUser(trader, amount);
	}

	function addLiquidatity(int256 cashToAdd) external syncState nonReentrant {
		require(cashToAdd > 0, Error.INVALID_COLLATERAL_AMOUNT);

		_transferFromUser(msg.sender, cashToAdd);
		int256 shareTotalSupply = IShareToken(_shareToken).totalSupply().toInt256();
		int256 shareToMint = _core.addLiquidity(shareTotalSupply, cashToAdd);
		uint256 unitInsuranceFund = shareTotalSupply > 0
			? _core.insuranceFund.wdiv(shareTotalSupply).toUint256()
			: 0;
		_core.updateCashBalance(address(this), cashToAdd);
		IShareToken(_shareToken).mint(msg.sender, shareToMint.toUint256(), unitInsuranceFund);

		emit AddLiquidatity(msg.sender, cashToAdd, shareToMint);
	}

	function removeLiquidatity(int256 shareToRemove) external syncState nonReentrant {
		require(shareToRemove > 0, Error.INVALID_COLLATERAL_AMOUNT);

		int256 shareTotalSupply = IShareToken(_shareToken).totalSupply().toInt256();
		int256 cashToReturn = _core.removeLiquidity(shareTotalSupply, shareToRemove);
		IShareToken(_shareToken).burn(msg.sender, shareToRemove.toUint256());
		_core.updateCashBalance(address(this), cashToReturn.neg());
		_transferToUser(payable(msg.sender), cashToReturn);

		emit RemoveLiquidatity(msg.sender, cashToReturn, shareToRemove);
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
	) external userTrace(order.trader) syncState {
		// signer
		address signer = order.signer(signature);
		require(signer == order.trader || isGranted(order.trader, signer, PRIVILEGE_TRADE), "");
		// validate
		_core.validateOrder(order, amount);
		// do trade
		_trade(order.trader, amount, order.priceLimit, order.deadline(), order.referrer);
	}

	function liquidateByAMM(address trader, uint256 deadline) external userTrace(trader) syncState {
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
		require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
		Receipt memory receipt = _core.liquidateByAMM(trader);
		emit LiquidateByAMM(
			trader,
			receipt.tradingAmount,
			receipt.tradingValue.wdiv(receipt.tradingAmount),
			receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee),
			deadline
		);
	}

	function liquidateByTrader(
		address trader,
		int256 amount,
		int256 priceLimit,
		uint256 deadline
	) external userTrace(msg.sender) userTrace(trader) syncState {
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
		require(amount != 0, Error.INVALID_POSITION_AMOUNT);
		require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
		require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);

		Receipt memory receipt = _core.liquidateToTrader(msg.sender, trader, amount, priceLimit);
		emit LiquidateByTrader(
			msg.sender,
			trader,
			receipt.tradingAmount,
			receipt.tradingValue.wdiv(receipt.tradingAmount),
			deadline
		);
	}

	function clear(address trader) external nonReentrant {
		_core.clear(trader);
		emit Clear(trader);
	}

	function settle(address trader) external auth(trader, PRIVILEGE_WITHDRAW) nonReentrant {
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);

		int256 withdrawable = _core.withdrawableMargin(trader);
		_core.updateCashBalance(trader, withdrawable.neg());
		_transferFromUser(trader, withdrawable);
		emit Withdraw(trader, withdrawable);
	}

	function _trade(
		address trader,
		int256 amount,
		int256 priceLimit,
		uint256 deadline,
		address referrer
	) internal userTrace(trader) syncState {
		require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
		require(amount != 0, Error.INVALID_POSITION_AMOUNT);
		require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
		require(deadline >= block.timestamp, Error.EXCEED_DEADLINE);
		Receipt memory receipt = _core.trade(trader, amount, priceLimit, referrer);
		emit Trade(
			trader,
			receipt.tradingAmount,
			receipt.tradingValue.wdiv(receipt.tradingAmount),
			receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(receipt.referrerFee),
			deadline
		);
	}

	bytes[50] private __gap;
}
