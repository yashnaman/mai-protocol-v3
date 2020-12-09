// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Events {
    // governance
    event UpdateCoreSetting(bytes32 key, int256 value);
    event UpdateRiskSetting(bytes32 key, int256 value, int256 minValue, int256 maxValue);
    event AdjustRiskSetting(bytes32 key, int256 value);

    // settle
    event Clear(address trader);
    // trade
    event Deposit(address trader, int256 amount);
    event Withdraw(address trader, int256 amount);
    event Trade(address indexed trader, int256 positionAmount, int256 price, int256 fee);
    event Liquidate(
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );
    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);
    event DonateInsuranceFund(address trader, int256 amount);
    // fee
    event ClaimFee(address claimer, int256 amount);
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
