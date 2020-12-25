// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Validator.sol";

import "../Type.sol";

library ParameterModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    function setPerpetualParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "initialMarginRate") {
            require(
                newValue < perpetual.initialMarginRate,
                "increasing initial margin rate is not allowed"
            );
            perpetual.initialMarginRate = newValue;
        } else if (key == "maintenanceMarginRate") {
            require(
                newValue < perpetual.maintenanceMarginRate,
                "increasing maintenance margin rate is not allowed"
            );
            perpetual.maintenanceMarginRate = newValue;
        } else if (key == "operatorFeeRate") {
            perpetual.operatorFeeRate = newValue;
        } else if (key == "lpFeeRate") {
            perpetual.lpFeeRate = newValue;
        } else if (key == "liquidationPenaltyRate") {
            perpetual.liquidationPenaltyRate = newValue;
        } else if (key == "keeperGasReward") {
            perpetual.keeperGasReward = newValue;
        } else if (key == "referrerRebateRate") {
            perpetual.referrerRebateRate = newValue;
        } else if (key == "insuranceFundRate") {
            perpetual.insuranceFundRate = newValue;
        } else if (key == "insuranceFundCap") {
            perpetual.insuranceFundCap = newValue;
        } else {
            revert("key not found");
        }
    }

    function updatePerpetualRiskParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "halfSpread") {
            adjustOption(perpetual.halfSpread, newValue);
        } else if (key == "openSlippageFactor") {
            adjustOption(perpetual.openSlippageFactor, newValue);
        } else if (key == "closeSlippageFactor") {
            adjustOption(perpetual.closeSlippageFactor, newValue);
        } else if (key == "fundingRateLimit") {
            adjustOption(perpetual.fundingRateLimit, newValue);
        } else if (key == "ammMaxLeverage") {
            adjustOption(perpetual.ammMaxLeverage, newValue);
        } else {
            revert("key not found");
        }
    }

    function setPerpetualRiskParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) public {
        if (key == "halfSpread") {
            setOption(perpetual.halfSpread, newValue, newMinValue, newMaxValue);
        } else if (key == "openSlippageFactor") {
            setOption(perpetual.openSlippageFactor, newValue, newMinValue, newMaxValue);
        } else if (key == "closeSlippageFactor") {
            setOption(perpetual.closeSlippageFactor, newValue, newMinValue, newMaxValue);
        } else if (key == "fundingRateLimit") {
            setOption(perpetual.fundingRateLimit, newValue, newMinValue, newMaxValue);
        } else if (key == "ammMaxLeverage") {
            setOption(perpetual.ammMaxLeverage, newValue, newMinValue, newMaxValue);
        } else {
            revert("key not found");
        }
    }

    function adjustOption(Option storage option, int256 newValue) internal {
        require(
            newValue >= option.minValue && newValue <= option.maxValue,
            "value is out of range"
        );
        option.value = newValue;
    }

    function setOption(
        Option storage option,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) internal {
        require(newValue >= newMinValue && newValue <= newMaxValue, "value is out of range");
        option.value = newValue;
        option.minValue = newMinValue;
        option.maxValue = newMaxValue;
    }

    function validateCoreParameters(PerpetualStorage storage perpetual) public view {
        require(perpetual.initialMarginRate > 0, "imr should be greater than 0");
        require(perpetual.maintenanceMarginRate > 0, "mmr should be greater than 0");
        require(
            perpetual.maintenanceMarginRate <= perpetual.initialMarginRate,
            "mmr should be lower than imr"
        );
        require(
            perpetual.operatorFeeRate >= 0 &&
                perpetual.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
            "ofr should be within [0, 0.01]"
        );
        require(
            perpetual.lpFeeRate >= 0 && perpetual.lpFeeRate <= (Constant.SIGNED_ONE / 100),
            "lp should be within [0, 0.01]"
        );
        require(
            perpetual.liquidationPenaltyRate >= 0 &&
                perpetual.liquidationPenaltyRate < perpetual.maintenanceMarginRate,
            "lpr should be non-negative and lower than mmr"
        );
        require(perpetual.keeperGasReward >= 0, "kgr should be non-negative");
    }

    function validateRiskParameters(PerpetualStorage storage perpetual) public view {
        require(perpetual.halfSpread.value >= 0 && perpetual.halfSpread.value < 1, "hsr shoud be greater than 0 and less than 1");
        require(perpetual.openSlippageFactor.value > 0, "beta1 shoud be greater than 0");
        require(
            perpetual.closeSlippageFactor.value > 0 &&
                perpetual.closeSlippageFactor.value <= perpetual.openSlippageFactor.value,
            "beta2 should be within (0, b1]"
        );
        require(perpetual.fundingRateLimit.value >= 0, "frl should be greater than 0");
        require(perpetual.ammMaxLeverage.value > 0, "aml should be greater than 0");
    }
}
