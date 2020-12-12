// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginModule.sol";
import "../module/ParameterModule.sol";
import "../Storage.sol";

contract TestMargin is Storage {
    using MarginModule for Market;
    using ParameterModule for Market;

    Market internal _market;

    constructor(address oracle) {
        _market.oracle = oracle;
        _market.state = MarketState.NORMAL;
    }

    function updateMarkPrice(int256 price) external {
        _market.markPriceData.price = price;
    }

    function initializeMarginAccount(
        address trader,
        int256 cashBalance,
        int256 positionAmount
    ) external {
        _market.marginAccounts[trader].cashBalance = cashBalance;
        _market.marginAccounts[trader].positionAmount = positionAmount;
    }

    function updateUnitAccumulativeFunding(int256 newUnitAccumulativeFunding) external {
        _market.unitAccumulativeFunding = newUnitAccumulativeFunding;
    }

    function updateMarketParameter(bytes32 key, int256 newValue) external {
        _market.updateMarketParameter(key, newValue);
    }

    function marginAccount(address trader)
        public
        view
        returns (int256 cashBalance, int256 positionAmount)
    {
        cashBalance = _market.marginAccounts[trader].cashBalance;
        positionAmount = _market.marginAccounts[trader].positionAmount;
    }

    function initialMargin(address trader) external view returns (int256) {
        return _market.initialMargin(trader);
    }

    function maintenanceMargin(address trader) external view returns (int256) {
        return _market.maintenanceMargin(trader);
    }

    function availableCashBalance(address trader) external view returns (int256) {
        return _market.availableCashBalance(trader);
    }

    function positionAmount(address trader) external view returns (int256) {
        return _market.positionAmount(trader);
    }

    function margin(address trader) external syncState returns (int256) {
        return _market.margin(trader);
    }

    function isInitialMarginSafe(address trader) external view returns (bool) {
        return _market.isInitialMarginSafe(trader);
    }

    function isMaintenanceMarginSafe(address trader) external view returns (bool) {
        return _market.isMaintenanceMarginSafe(trader);
    }

    function isEmptyAccount(address trader) external view returns (bool) {
        return _market.isEmptyAccount(trader);
    }

    function updateMarginAccount(
        address trader,
        int256 deltaPositionAmount,
        int256 deltaMargin
    ) external returns (int256, int256){
        _market.updateMarginAccount(trader, deltaPositionAmount, deltaMargin);
        return marginAccount(trader);
    }
}
