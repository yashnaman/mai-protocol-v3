// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginModule.sol";
import "../module/PerpetualModule.sol";
import "../module/TradeModule.sol";
import "../module/ParameterModule.sol";

import "../Type.sol";
import "../Storage.sol";
import "../Getter.sol";

contract TestTrade is Storage, Getter {
    using PerpetualModule for PerpetualStorage;
    using MarginModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;
    using TradeModule for PerpetualStorage;
    using ParameterModule for LiquidityPoolStorage;
    using ParameterModule for PerpetualStorage;

    Receipt public tempReceipt;

    function createPerpetual(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 perpetualIndex = _liquidityPool.perpetuals.length;
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals.push();
        perpetual.initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        perpetual.state = PerpetualState.NORMAL;
    }

    function setUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding)
        public
    {
        _liquidityPool.perpetuals[perpetualIndex].unitAccumulativeFunding = unitAccumulativeFunding;
    }

    function setOperator(address operator) public {
        _liquidityPool.operator = operator;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _liquidityPool.vault = vault;
        _liquidityPool.vaultFeeRate = vaultFeeRate;
    }

    function updateLiquidityPoolParameter(bytes32 key, int256 newValue) external {
        _liquidityPool.updateLiquidityPoolParameter(key, newValue);
    }

    function updatePerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].updatePerpetualParameter(key, newValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].updatePerpetualRiskParameter(
            key,
            newValue,
            newValue,
            newValue
        );
    }

    function initializeMarginAccount(
        uint256 perpetualIndex,
        address trader,
        int256 cashBalance,
        int256 positionAmount
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader].cashBalance = cashBalance;
        _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader]
            .positionAmount = positionAmount;
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer);
    }

    function updateTradingFees(
        uint256 perpetualIndex,
        Receipt memory receipt,
        address referrer
    ) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.updateTradingFees(perpetual, receipt, referrer);
    }

    function updateTradingResult(
        uint256 perpetualIndex,
        Receipt memory receipt,
        address taker,
        address maker
    ) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateTradingResult(receipt, taker, maker);
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 limitPrice
    ) public pure {
        TradeModule.validatePrice(amount, price, limitPrice);
    }
}
