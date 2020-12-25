// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Events {
    // settle
    event ClearAccount(uint256 perpetualIndex, address trader);
    event SettleAccount(uint256 perpetualIndex, address trader, int256 amount);
    // trade
    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);
    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 position,
        int256 price,
        int256 fee
    );
    event Liquidate(
        uint256 perpetualIndex,
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
    // state
    event EnterNormalState(uint256 perpetualIndex);
    event EnterEmergencyState(
        uint256 perpetualIndex,
        int256 settlementPrice,
        uint256 settlementTime
    );
    event EnterClearedState(uint256 perpetualIndex);
}
