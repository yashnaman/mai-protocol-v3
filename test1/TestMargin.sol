// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";
import "../Storage.sol";

contract TestMargin is Storage {
    using MarginAccountModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

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

    function updateMarkPrice(uint256 perpetualIndex, int256 price) external {
        _liquidityPool.perpetuals[perpetualIndex].markPriceData.price = price;
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

    function updateUnitAccumulativeFunding(
        uint256 perpetualIndex,
        int256 newUnitAccumulativeFunding
    ) external {
        _liquidityPool.perpetuals[perpetualIndex]
            .unitAccumulativeFunding = newUnitAccumulativeFunding;
    }

    function setPerpetualParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.perpetuals[perpetualIndex].setPerpetualParameter(key, newValue);
    }

    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        view
        returns (int256 cash, int256 position)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        cash = perpetual.marginAccounts[trader].cash;
        position = perpetual.marginAccounts[trader].position;
    }

    function getInitialMargin(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getInitialMargin(trader, perpetual.getMarkPrice());
    }

    function getMaintenanceMargin(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getMaintenanceMargin(trader, perpetual.getMarkPrice());
    }

    function getAvailableCash(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getAvailableCash(trader);
    }

    function getPosition(uint256 perpetualIndex, address trader) external view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getPosition(trader);
    }

    function getMargin(uint256 perpetualIndex, address trader) external syncState returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getMargin(trader, perpetual.getMarkPrice());
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

    function updateMargin(
        uint256 perpetualIndex,
        address trader,
        int256 deltaPosition,
        int256 deltaCash
    ) external returns (int256, int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateMargin(trader, deltaPosition, deltaCash);
        return getMarginAccount(perpetualIndex, trader);
    }
}
