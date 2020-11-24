// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Validator.sol";

import "../Type.sol";

library ParameterModule {
	using SafeMathExt for int256;
	using SignedSafeMath for int256;

	function updateCoreParameter(
		Core storage core,
		bytes32 key,
		int256 newValue
	) public {
		if (key == "initialMarginRate") {
			core.initialMarginRate = newValue;
		} else if (key == "maintenanceMarginRate") {
			core.maintenanceMarginRate = newValue;
		} else if (key == "operatorFeeRate") {
			core.operatorFeeRate = newValue;
		} else if (key == "lpFeeRate") {
			core.lpFeeRate = newValue;
		} else if (key == "liquidationPenaltyRate") {
			core.lpFeeRate = newValue;
		} else if (key == "keeperGasReward") {
			core.keeperGasReward = newValue;
		} else {
			revert("key not found");
		}
		isCoreParameterValid(core);
	}

	function adjustRiskParameter(
		Core storage core,
		bytes32 key,
		int256 newValue
	) public {
		if (key == "halfSpreadRate") {
			adjustOption(core.halfSpreadRate, newValue);
		} else if (key == "beta1") {
			adjustOption(core.beta1, newValue);
		} else if (key == "beta2") {
			adjustOption(core.beta2, newValue);
		} else if (key == "fundingRateCoefficient") {
			adjustOption(core.fundingRateCoefficient, newValue);
		} else if (key == "targetLeverage") {
			adjustOption(core.targetLeverage, newValue);
		} else {
			revert("key not found");
		}
		isRiskParameterValid(core);
	}

	function updateRiskParameter(
		Core storage core,
		bytes32 key,
		int256 newValue,
		int256 newMinValue,
		int256 newMaxValue
	) public {
		if (key == "halfSpreadRate") {
			updateOption(core.halfSpreadRate, newValue, newMinValue, newMaxValue);
		} else if (key == "beta1") {
			updateOption(core.beta1, newValue, newMinValue, newMaxValue);
		} else if (key == "beta2") {
			updateOption(core.beta2, newValue, newMinValue, newMaxValue);
		} else if (key == "fundingRateCoefficient") {
			updateOption(core.fundingRateCoefficient, newValue, newMinValue, newMaxValue);
		} else if (key == "targetLeverage") {
			updateOption(core.targetLeverage, newValue, newMinValue, newMaxValue);
		} else {
			revert("key not found");
		}
		isRiskParameterValid(core);
	}

	function adjustOption(Option storage option, int256 newValue) internal {
		require(newValue >= option.minValue && newValue <= option.maxValue, "");
		option.value = newValue;
	}

	function updateOption(
		Option storage option,
		int256 newValue,
		int256 newMinValue,
		int256 newMaxValue
	) internal {
		option.value = newValue;
		option.minValue = newMinValue;
		option.maxValue = newMaxValue;
	}

	function isCoreParameterValid(Core storage core) public view {
		require(core.initialMarginRate > 0 && core.initialMarginRate <= Constant.SIGNED_ONE, "");
		require(
			core.maintenanceMarginRate > 0 && core.maintenanceMarginRate <= Constant.SIGNED_ONE,
			""
		);
		require(core.maintenanceMarginRate <= core.initialMarginRate, "");
		require(
			core.operatorFeeRate >= 0 && core.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
			""
		);
		require(core.vaultFeeRate >= 0, "");
		require(core.lpFeeRate >= 0 && core.lpFeeRate <= (Constant.SIGNED_ONE / 100), "");
		require(
			core.liquidationPenaltyRate >= 0 &&
				core.liquidationPenaltyRate < core.maintenanceMarginRate,
			""
		);
		require(core.keeperGasReward >= 0, "");
	}

	function isRiskParameterValid(Core storage core) public view {
		require(core.halfSpreadRate.value >= 0, "");
		require(core.beta1.value > 0 && core.beta1.value < Constant.SIGNED_ONE, "");
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
