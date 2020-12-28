// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract LibraryEvents {
    // settle
    event ClearAccount(uint256 perpetualIndex, address trader);
    event SettleAccount(uint256 perpetualIndex, address trader, int256 amount);
    // perpetual
    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);
    event Clear(uint256 perpetualIndex, address trader);
    event Settle(uint256 perpetualIndex, address trader, int256 amount);
    event DonateInsuranceFund(uint256 perpetualIndex, int256 amount);
    event SetNormalState(uint256 perpetualIndex);
    event SetEmergencyState(uint256 perpetualIndex, int256 settlementPrice, uint256 settlementTime);
    event SetClearedState(uint256 perpetualIndex);
    event UpdateUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding);
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
    event IncreaseFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);
    event UpdatePoolMargin(int256 poolMargin);
}
