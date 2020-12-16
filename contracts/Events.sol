// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Events {
    // governance
    event UpdateLiquidityPoolParameter(bytes32 key, int256 value);
    event UpdateMarketParameter(uint256 marketIndex, bytes32 key, int256 value);
    event UpdateMarketRiskParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 value,
        int256 minValue,
        int256 maxValue
    );

    event AdjustMarketRiskSetting(uint256 marketIndex, bytes32 key, int256 value);

    // settle
    event Clear(uint256 marketIndex, address trader);
    event Settle(uint256 marketIndex, address trader, int256 amount);
    // trade
    event Deposit(uint256 marketIndex, address trader, int256 amount);
    event Withdraw(uint256 marketIndex, address trader, int256 amount);
    event Trade(
        uint256 marketIndex,
        address indexed trader,
        int256 positionAmount,
        int256 price,
        int256 fee
    );
    event Liquidate(
        uint256 marketIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );
    // pool
    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);
    event DonateInsuranceFund(address trader, int256 amount);
    // fee
    event ClaimFee(address claimer, int256 amount);
}
