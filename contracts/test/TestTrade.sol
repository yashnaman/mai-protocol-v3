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

    function createPerpetual(
        address oracle,
        int256[9] calldata coreParams,
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

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].setPerpetualRiskParameter(
            key,
            newValue,
            newValue,
            newValue
        );
    }

    function initializeMarginAccount(
        uint256 perpetualIndex,
        address trader,
        int256 cash,
        int256 position
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader].cash = cash;
        _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader].position = position;
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        bool isCloseOnly
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, isCloseOnly);
    }

    function updateFees(
        uint256 perpetualIndex,
        int256 value,
        address referrer
    ) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.updateFees(perpetual, value, referrer);
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 limitPrice
    ) public pure {
        TradeModule.validatePrice(isLong, price, limitPrice);
    }
}
