// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginModule.sol";
import "../module/TradeModule.sol";
import "../module/ParameterModule.sol";

import "../Type.sol";
import "../Storage.sol";
import "./TestMargin.sol";

contract TestTrade is Storage, TestMargin {
    using MarginModule for Core;
    using TradeModule for Core;
    using ParameterModule for Core;

    Receipt public tempReceipt;

    constructor(address oracle) TestMargin(oracle) {
    }

    function updateIndexPrice(int256 price) external {
        _core.indexPriceData.price = price;
    }

    function setOperator(address operator) public {
        _core.operator = operator;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _core.vault = vault;
        _core.vaultFeeRate = vaultFeeRate;
    }

    function updateRiskParameter(bytes32 key, int256 newValue) external {
        _core.updateRiskParameter(key, newValue, newValue, newValue);
    }

    function trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public {
        _core.trade(trader, amount, priceLimit, referrer);
    }

    function liquidateByAMM(address trader) public {
        _core.liquidateByAMM(trader);
    }

    function liquidateByTrader(
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public {
        _core.liquidateByTrader(taker, maker, amount, priceLimit);
    }

    function updateTradingResult(
        Receipt memory receipt,
        address taker,
        address maker,
        address referrer
    ) public {
        _core.updateTradingResult(receipt, taker, maker, referrer);
        tempReceipt = receipt;
    }

    function updateTradingFees(Receipt memory receipt, address referrer)
        public
        view
        returns (Receipt memory)
    {
        _core.updateTradingFees(receipt, referrer);
        return receipt;
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) public pure {
        TradeModule.validatePrice(amount, price, priceLimit);
    }

    function updateInsuranceFund(int256 fund) public {
        _core.updateInsuranceFund(fund);
    }
}
