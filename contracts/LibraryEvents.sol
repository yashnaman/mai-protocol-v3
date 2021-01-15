// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract LibraryEvents {
    // perpetual
    event Deposit(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Clear(uint256 perpetualIndex, address indexed trader);
    event Settle(uint256 perpetualIndex, address indexed trader, int256 amount);
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
        int256 price,
        int256 penalty
    );

    event SetPerpetualBaseParameter(uint256 perpetualIndex, bytes32 key, int256 value);
    event SetPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 value,
        int256 minValue,
        int256 maxValue
    );
    event UpdatePerpetualRiskParameter(uint256 perpetualIndex, bytes32 key, int256 value);

    // pool
    event AddLiquidity(address indexed trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address indexed trader, int256 returnedCash, int256 burnedShare);
    event IncreaseFee(address indexed recipient, int256 amount);
    event ClaimFee(address indexed claimer, int256 amount);
    event UpdatePoolMargin(int256 poolMargin);
    event TransferOperatorTo(address indexed newOperator);
    event ClaimOperatorTo(address indexed newOperator);
    event RevokeOperator();
    event SetLiquidityPoolParameter(bytes32 key, int256 value);
    event CreatePerpetual(
        uint256 perpetualIndex,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        address collateral,
        int256[9] coreParams,
        int256[6] riskParams
    );
    event RunLiquidityPool();
}
