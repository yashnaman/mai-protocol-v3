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

    function updateLiquidityPoolParameter(
        Core storage core,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "insuranceFundCap") {
            core.insuranceFundCap = newValue;
        } else {
            revert("key not found");
        }
    }

    function updateMarketParameter(
        Market storage market,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "initialMarginRate") {
            require(
                newValue < market.initialMarginRate,
                "increasing initial margin rate is not allowed"
            );
            market.initialMarginRate = newValue;
        } else if (key == "maintenanceMarginRate") {
            require(
                newValue < market.maintenanceMarginRate,
                "increasing maintenance margin rate is not allowed"
            );
            market.maintenanceMarginRate = newValue;
        } else if (key == "operatorFeeRate") {
            market.operatorFeeRate = newValue;
        } else if (key == "lpFeeRate") {
            market.lpFeeRate = newValue;
        } else if (key == "liquidationPenaltyRate") {
            market.liquidationPenaltyRate = newValue;
        } else if (key == "keeperGasReward") {
            market.keeperGasReward = newValue;
        } else if (key == "referrerRebateRate") {
            market.referrerRebateRate = newValue;
        } else if (key == "insuranceFundRate") {
            market.insuranceFundRate = newValue;
        } else {
            revert("key not found");
        }
    }

    function adjustMarketRiskParameter(
        Market storage market,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "spread") {
            adjustOption(market.spread, newValue);
        } else if (key == "openSlippage") {
            adjustOption(market.openSlippage, newValue);
        } else if (key == "closeSlippage") {
            adjustOption(market.closeSlippage, newValue);
        } else if (key == "fundingRateCoefficient") {
            adjustOption(market.fundingRateCoefficient, newValue);
        } else if (key == "maxLeverage") {
            adjustOption(market.maxLeverage, newValue);
        } else {
            revert("key not found");
        }
    }

    function updateMarketRiskParameter(
        Market storage market,
        bytes32 key,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) public {
        if (key == "spread") {
            updateOption(market.spread, newValue, newMinValue, newMaxValue);
        } else if (key == "openSlippage") {
            updateOption(market.openSlippage, newValue, newMinValue, newMaxValue);
        } else if (key == "closeSlippage") {
            updateOption(market.closeSlippage, newValue, newMinValue, newMaxValue);
        } else if (key == "fundingRateCoefficient") {
            updateOption(market.fundingRateCoefficient, newValue, newMinValue, newMaxValue);
        } else if (key == "maxLeverage") {
            updateOption(market.maxLeverage, newValue, newMinValue, newMaxValue);
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

    function updateOption(
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

    function validateCoreParameters(Market storage market) public view {
        require(
            market.initialMarginRate > 0 && market.initialMarginRate <= Constant.SIGNED_ONE,
            "imr should be greater than 0"
        );
        require(
            market.maintenanceMarginRate > 0 && market.maintenanceMarginRate <= Constant.SIGNED_ONE,
            "mmr should be greater than 0"
        );
        require(
            market.maintenanceMarginRate <= market.initialMarginRate,
            "mmr should be lower than imr"
        );
        require(
            market.operatorFeeRate >= 0 && market.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
            "ofr should be within [0, 0.01]"
        );
        require(
            market.lpFeeRate >= 0 && market.lpFeeRate <= (Constant.SIGNED_ONE / 100),
            "lp should be within [0, 0.01]"
        );
        require(
            market.liquidationPenaltyRate >= 0 &&
                market.liquidationPenaltyRate < market.maintenanceMarginRate,
            "lpr should be non-negative and lower than mmr"
        );
        require(market.keeperGasReward >= 0, "kgr should be non-negative");
    }

    function validateRiskParameters(Market storage market) public view {
        require(market.spread.value >= 0, "hsr shoud be greater than 0");
        require(
            market.openSlippage.value > 0 && market.openSlippage.value < Constant.SIGNED_ONE,
            "b1 should be within (0, 1)"
        );
        require(
            market.closeSlippage.value > 0 &&
                market.closeSlippage.value < Constant.SIGNED_ONE &&
                market.closeSlippage.value < market.openSlippage.value,
            "b2 should be within (0, b1)"
        );
        require(market.fundingRateCoefficient.value >= 0, "frc should be greater than 0");
        require(
            market.maxLeverage.value > Constant.SIGNED_ONE &&
                market.maxLeverage.value < Constant.SIGNED_ONE * 10,
            "tl should be within (1, 10)"
        );
    }
}
