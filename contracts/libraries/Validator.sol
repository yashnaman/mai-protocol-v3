// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Constant.sol";
import "../Type.sol";

library Validator {
    function isCoreParameterValid(Core storage core) public view {
        require(
            core.initialMarginRate > 0 &&
                core.initialMarginRate <= Constant.SIGNED_ONE,
            ""
        );
        require(
            core.maintenanceMarginRate > 0 &&
                core.maintenanceMarginRate <= Constant.SIGNED_ONE,
            ""
        );
        require(core.maintenanceMarginRate <= core.initialMarginRate, "");
        require(
            core.operatorFeeRate >= 0 &&
                core.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
            ""
        );
        require(core.vaultFeeRate >= 0, "");
        require(
            core.lpFeeRate >= 0 &&
                core.lpFeeRate <= (Constant.SIGNED_ONE / 100),
            ""
        );
        require(
            core.liquidationPenaltyRate >= 0 &&
                core.liquidationPenaltyRate < core.maintenanceMarginRate,
            ""
        );
        require(core.keeperGasReward >= 0, "");
    }

    function isRiskParameterValid(Core storage core) public view {
        require(core.halfSpreadRate.value >= 0, "");
        require(
            core.beta1.value > 0 && core.beta1.value < Constant.SIGNED_ONE,
            ""
        );
        require(
            core.beta2.value > 0 &&
                core.beta2.value < Constant.SIGNED_ONE &&
                core.beta2.value < core.beta1.value,
            ""
        );
        require(
            core.beta2.value > 0 &&
                core.beta2.value < Constant.SIGNED_ONE &&
                core.beta2.value < core.beta1.value,
            ""
        );
        require(core.fundingRateCoefficient.value >= 0, "");
        require(
            core.targetLeverage.value > Constant.SIGNED_ONE &&
                core.targetLeverage.value < Constant.SIGNED_ONE * 10,
            ""
        );
    }
}
