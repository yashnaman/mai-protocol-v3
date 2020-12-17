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
    using PerpetualModule for Perpetual;
    using MarginModule for Core;
    using TradeModule for Core;
    using TradeModule for Perpetual;
    using ParameterModule for Core;
    using ParameterModule for Perpetual;

    Receipt public tempReceipt;

    function createPerpetual(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 perpetualIndex = _core.perpetuals.length;
        Perpetual storage perpetual = _core.perpetuals.push();
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
        _core.perpetuals[perpetualIndex].unitAccumulativeFunding = unitAccumulativeFunding;
    }

    function setOperator(address operator) public {
        _core.operator = operator;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _core.vault = vault;
        _core.vaultFeeRate = vaultFeeRate;
    }

    function updateLiquidityPoolParameter(bytes32 key, int256 newValue) external {
        _core.updateLiquidityPoolParameter(key, newValue);
    }

    function updatePerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _core.perpetuals[perpetualIndex].updatePerpetualParameter(key, newValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _core.perpetuals[perpetualIndex].updatePerpetualRiskParameter(
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
        _core.perpetuals[perpetualIndex].marginAccounts[trader].cashBalance = cashBalance;
        _core.perpetuals[perpetualIndex].marginAccounts[trader].positionAmount = positionAmount;
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public syncState {
        _core.trade(perpetualIndex, trader, amount, priceLimit, referrer);
    }

    function updateTradingFees(
        uint256 perpetualIndex,
        Receipt memory receipt,
        address referrer
    ) public {
        Perpetual storage perpetual = _core.perpetuals[perpetualIndex];
        _core.updateTradingFees(perpetual, receipt, referrer);
    }

    function updateTradingResult(
        uint256 perpetualIndex,
        Receipt memory receipt,
        address taker,
        address maker
    ) public {
        Perpetual storage perpetual = _core.perpetuals[perpetualIndex];
        perpetual.updateTradingResult(receipt, taker, maker);
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) public pure {
        TradeModule.validatePrice(amount, price, priceLimit);
    }
}
