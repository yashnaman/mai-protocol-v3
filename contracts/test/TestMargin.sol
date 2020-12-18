// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";
import "../module/PerpetualModule.sol";
import "../Storage.sol";

contract TestMargin is Storage {
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using ParameterModule for PerpetualStorage;

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

    function updateMarkPrice(uint256 perpetualIndex, int256 price) external {
        _liquidityPool.perpetuals[perpetualIndex].markPriceData.price = price;
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

    function updateUnitAccumulativeFunding(
        uint256 perpetualIndex,
        int256 newUnitAccumulativeFunding
    ) external {
        _liquidityPool.perpetuals[perpetualIndex]
            .unitAccumulativeFunding = newUnitAccumulativeFunding;
    }

    function updatePerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].updatePerpetualParameter(key, newValue);
    }

    function marginAccount(uint256 perpetualIndex, address trader)
        public
        view
        returns (int256 cashBalance, int256 positionAmount)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        cashBalance = perpetual.marginAccounts[trader].cashBalance;
        positionAmount = perpetual.marginAccounts[trader].positionAmount;
    }

    function initialMargin(uint256 perpetualIndex, address trader) external view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.initialMargin(trader, perpetual.markPrice());
    }

    function maintenanceMargin(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.maintenanceMargin(trader, perpetual.markPrice());
    }

    function availableCashBalance(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.availableCashBalance(trader);
    }

    function positionAmount(uint256 perpetualIndex, address trader) external view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.positionAmount(trader);
    }

    function margin(uint256 perpetualIndex, address trader) external syncState returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.margin(trader, perpetual.markPrice());
    }

    function isInitialMarginSafe(uint256 perpetualIndex, address trader)
        external
        view
        returns (bool)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isInitialMarginSafe(trader);
    }

    function isMaintenanceMarginSafe(uint256 perpetualIndex, address trader)
        external
        view
        returns (bool)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isMaintenanceMarginSafe(trader);
    }

    function isEmptyAccount(uint256 perpetualIndex, address trader) external view returns (bool) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isEmptyAccount(trader);
    }

    function updateMarginAccount(
        uint256 perpetualIndex,
        address trader,
        int256 deltaPositionAmount,
        int256 deltaMargin
    ) external returns (int256, int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateMarginAccount(trader, deltaPositionAmount, deltaMargin);
        return marginAccount(perpetualIndex, trader);
    }
}
