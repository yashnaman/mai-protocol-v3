// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/Utils.sol";

import "../module/ParameterModule.sol";
import "../module/OracleModule.sol";

import "../Type.sol";

library PerpetualModule {
    using SignedSafeMathUpgradeable for int256;
    using ParameterModule for Perpetual;
    using ParameterModule for Option;
    using OracleModule for Perpetual;

    event EnterNormalState();
    event EnterEmergencyState(int256 settlementPrice, uint256 settlementTime);
    event EnterClearedState();

    function initialize(
        Perpetual storage perpetual,
        uint256 id,
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) public {
        perpetual.id = id;
        perpetual.oracle = oracle;

        perpetual.initialMarginRate = coreParams[0];
        perpetual.maintenanceMarginRate = coreParams[1];
        perpetual.operatorFeeRate = coreParams[2];
        perpetual.lpFeeRate = coreParams[3];
        perpetual.referrerRebateRate = coreParams[4];
        perpetual.liquidationPenaltyRate = coreParams[5];
        perpetual.keeperGasReward = coreParams[6];
        perpetual.insuranceFundRate = coreParams[7];
        perpetual.validateCoreParameters();

        perpetual.halfSpread.updateOption(
            riskParams[0],
            minRiskParamValues[0],
            maxRiskParamValues[0]
        );
        perpetual.openSlippageFactor.updateOption(
            riskParams[1],
            minRiskParamValues[1],
            maxRiskParamValues[1]
        );
        perpetual.closeSlippageFactor.updateOption(
            riskParams[2],
            minRiskParamValues[2],
            maxRiskParamValues[2]
        );
        perpetual.fundingRateLimit.updateOption(
            riskParams[3],
            minRiskParamValues[3],
            maxRiskParamValues[3]
        );
        perpetual.maxLeverage.updateOption(
            riskParams[4],
            minRiskParamValues[4],
            maxRiskParamValues[4]
        );
        perpetual.validateRiskParameters();
        perpetual.state = PerpetualState.INITIALIZING;
    }

    function increaseDepositedCollateral(Perpetual storage perpetual, int256 amount) public {
        require(amount >= 0, "amount is negative");
        perpetual.depositedCollateral = perpetual.depositedCollateral.add(amount);
    }

    function decreaseDepositedCollateral(Perpetual storage perpetual, int256 amount) public {
        require(amount >= 0, "amount is negative");
        perpetual.depositedCollateral = perpetual.depositedCollateral.sub(amount);
        require(perpetual.depositedCollateral >= 0, "collateral is negative");
    }

    function enterNormalState(Perpetual storage perpetual) internal {
        require(
            perpetual.state == PerpetualState.INITIALIZING,
            "perpetual should be in initializing state"
        );
        perpetual.state = PerpetualState.NORMAL;
        emit EnterNormalState();
    }

    function enterEmergencyState(Perpetual storage perpetual) internal {
        require(perpetual.state == PerpetualState.NORMAL, "perpetual should be in normal state");
        perpetual.updatePrice();
        perpetual.freezeOraclePrice();
        perpetual.state = PerpetualState.EMERGENCY;
        emit EnterEmergencyState(
            perpetual.settlementPriceData.price,
            perpetual.settlementPriceData.time
        );
    }

    function enterClearedState(Perpetual storage perpetual) internal {
        require(perpetual.state == PerpetualState.EMERGENCY, "perpetual should be in normal state");
        perpetual.state = PerpetualState.CLEARED;
        emit EnterClearedState();
    }
}
