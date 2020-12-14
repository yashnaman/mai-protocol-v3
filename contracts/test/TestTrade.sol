// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginModule.sol";
import "../module/MarketModule.sol";
import "../module/TradeModule.sol";
import "../module/ParameterModule.sol";

import "../Type.sol";
import "../Storage.sol";
import "../Getter.sol";

contract TestTrade is Storage, Getter {
    using MarketModule for Market;
    using MarginModule for Core;
    using TradeModule for Core;
    using TradeModule for Market;
    using ParameterModule for Core;
    using ParameterModule for Market;

    Receipt public tempReceipt;

    function createMarket(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        uint256 marketIndex = _core.markets.length;
        Market storage market = _core.markets.push();
        market.initialize(
            marketIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        market.state = MarketState.NORMAL;
    }

    function setUnitAccumulativeFunding(uint256 marketIndex, int256 unitAccumulativeFunding)
        public
    {
        _core.markets[marketIndex].unitAccumulativeFunding = unitAccumulativeFunding;
    }

    function setOperator(address operator) public {
        _core.operator = operator;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _core.vault = vault;
        _core.vaultFeeRate = vaultFeeRate;
    }

    function updateSharedLiquidityPoolParameter(bytes32 key, int256 newValue) external {
        _core.updateSharedLiquidityPoolParameter(key, newValue);
    }

    function updateMarketParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _core.markets[marketIndex].updateMarketParameter(key, newValue);
    }

    function updateMarketRiskParameter(
        uint256 marketIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _core.markets[marketIndex].updateMarketRiskParameter(key, newValue, newValue, newValue);
    }

    function initializeMarginAccount(
        uint256 marketIndex,
        address trader,
        int256 cashBalance,
        int256 positionAmount
    ) external {
        _core.markets[marketIndex].marginAccounts[trader].cashBalance = cashBalance;
        _core.markets[marketIndex].marginAccounts[trader].positionAmount = positionAmount;
    }

    function trade(
        uint256 marketIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public syncState {
        _core.trade(marketIndex, trader, amount, priceLimit, referrer);
    }

    function updateTradingFees(
        uint256 marketIndex,
        Receipt memory receipt,
        address referrer
    ) public {
        Market storage market = _core.markets[marketIndex];
        _core.updateTradingFees(market, receipt, referrer);
    }

    function updateTradingResult(
        uint256 marketIndex,
        Receipt memory receipt,
        address taker,
        address maker
    ) public {
        Market storage market = _core.markets[marketIndex];
        market.updateTradingResult(receipt, taker, maker);
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) public pure {
        TradeModule.validatePrice(amount, price, priceLimit);
    }
}
