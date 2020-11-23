// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Events {
	event Deposit(address trader, int256 amount);
	event Withdraw(address trader, int256 amount);
	event Clear(address trader);
	event AddLiquidatity(address trader, int256 amount);
	event RemoveLiquidatity(address trader, int256 amount);
	event DonateInsuranceFund(address trader, int256 amount);
	event UpdateCoreSetting(bytes32 key, int256 value);
	event UpdateRiskSetting(bytes32 key, int256 value, int256 minValue, int256 maxValue);
	event AdjustRiskSetting(bytes32 key, int256 value);
	event ClaimFee(address claimer, int256 amount);
	event Trade(
		address indexed trader,
		int256 positionAmount,
		int256 priceLimit,
		int256 fee,
		uint256 deadline
	);
	event LiquidateByAMM(
		address indexed trader,
		int256 amount,
		int256 price,
		int256 fee,
		uint256 deadline
	);
	event LiquidateByTrader(
		address indexed liquidator,
		address indexed trader,
		int256 amount,
		int256 price,
		uint256 deadline
	);

	// trick, to watch events fired from libraries
	event ClosePositionByTrade(address trader, int256 amount, int256 price, int256 fundingLoss);
	event OpenPositionByTrade(address trader, int256 amount, int256 price);
	event ClosePositionByLiquidation(
		address trader,
		int256 amount,
		int256 price,
		int256 fundingLoss
	);
	event OpenPositionByLiquidation(address trader, int256 amount, int256 price);
}
