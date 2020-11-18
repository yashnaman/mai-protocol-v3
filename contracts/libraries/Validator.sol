// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Constant.sol";
import "../Type.sol";

library Validator {
    function validate(CoreParameter storage param) public view {
        require(
            param.initialMarginRate > 0 &&
                param.initialMarginRate <= Constant.SIGNED_ONE,
            ""
        );
        require(
            param.maintenanceMarginRate > 0 &&
                param.maintenanceMarginRate <= Constant.SIGNED_ONE,
            ""
        );
        require(param.maintenanceMarginRate <= param.initialMarginRate, "");
        require(
            param.operatorFeeRate >= 0 &&
                param.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
            ""
        );
        require(param.vaultFeeRate >= 0, "");
        require(
            param.lpFeeRate >= 0 &&
                param.lpFeeRate <= (Constant.SIGNED_ONE / 100),
            ""
        );
        require(
            param.liquidationPenaltyRate >= 0 &&
                param.liquidationPenaltyRate < param.maintenanceMarginRate,
            ""
        );
        require(param.keeperGasReward >= 0, "");
    }

    function validate(RiskParameter storage param) public view {
        require(param.halfSpreadRate.value >= 0, "");
        require(
            param.beta1.value > 0 && param.beta1.value < Constant.SIGNED_ONE,
            ""
        );
        require(
            param.beta2.value > 0 &&
                param.beta2.value < Constant.SIGNED_ONE &&
                param.beta2.value < param.beta1.value,
            ""
        );
        require(
            param.beta2.value > 0 &&
                param.beta2.value < Constant.SIGNED_ONE &&
                param.beta2.value < param.beta1.value,
            ""
        );
        require(param.fundingRateCoefficient.value >= 0, "");
        require(
            param.targetLeverage.value > Constant.SIGNED_ONE &&
                param.targetLeverage.value < Constant.SIGNED_ONE * 10,
            ""
        );
    }
}
