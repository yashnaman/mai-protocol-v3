// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";
import "../Storage.sol";

contract TestMargin is Storage {
    using MarginModule for PerpetualStorage;
    using ParameterModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    PerpetualStorage internal _perpetual;

    constructor(address oracle) {
        _perpetual.oracle = oracle;
        _perpetual.state = PerpetualState.NORMAL;
    }

    function updateMarkPrice(int256 price) external {
        _perpetual.markPriceData.price = price;
    }

    function initializeMarginAccount(
        address trader,
        int256 cashBalance,
        int256 positionAmount
    ) external {
        _perpetual.marginAccounts[trader].cashBalance = cashBalance;
        _perpetual.marginAccounts[trader].positionAmount = positionAmount;
    }

    function updateUnitAccumulativeFunding(int256 newUnitAccumulativeFunding) external {
        _perpetual.unitAccumulativeFunding = newUnitAccumulativeFunding;
    }

    function updatePerpetualParameter(bytes32 key, int256 newValue) external {
        _perpetual.updatePerpetualParameter(key, newValue);
    }

    function marginAccount(address trader)
        public
        view
        returns (int256 cashBalance, int256 positionAmount)
    {
        cashBalance = _perpetual.marginAccounts[trader].cashBalance;
        positionAmount = _perpetual.marginAccounts[trader].positionAmount;
    }

    function initialMargin(address trader) external view returns (int256) {
        return _perpetual.initialMargin(trader, _perpetual.markPrice());
    }

    function maintenanceMargin(address trader) external view returns (int256) {
        return _perpetual.maintenanceMargin(trader, _perpetual.markPrice());
    }

    function availableCashBalance(address trader) external view returns (int256) {
        return _perpetual.availableCashBalance(trader);
    }

    function positionAmount(address trader) external view returns (int256) {
        return _perpetual.positionAmount(trader);
    }

    function margin(address trader) external syncState returns (int256) {
        return _perpetual.margin(trader, _perpetual.markPrice());
    }

    function isInitialMarginSafe(address trader) external view returns (bool) {
        return _perpetual.isInitialMarginSafe(trader);
    }

    function isMaintenanceMarginSafe(address trader) external view returns (bool) {
        return _perpetual.isMaintenanceMarginSafe(trader);
    }

    function isEmptyAccount(address trader) external view returns (bool) {
        return _perpetual.isEmptyAccount(trader);
    }

    function updateMarginAccount(
        address trader,
        int256 deltaPositionAmount,
        int256 deltaMargin
    ) external returns (int256, int256){
        _perpetual.updateMarginAccount(trader, deltaPositionAmount, deltaMargin);
        return marginAccount(trader);
    }
}
