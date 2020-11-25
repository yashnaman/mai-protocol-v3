// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./interface/IFactory.sol";

import "./Type.sol";
import "./module/FundingModule.sol";
import "./module/OracleModule.sol";
import "./module/ParameterModule.sol";

contract Storage {
	address internal _governor;
	address internal _shareToken;
	Core internal _core;

	using FundingModule for Core;
	using OracleModule for Core;
	using ParameterModule for Core;
	using ParameterModule for Option;

	modifier syncState() {
		_core.updateFundingState();
		_core.updatePrice();
		_;
		_core.updateFundingRate();
	}

	function _storageInitialize(
		address operator,
		address oracle,
		address governor_,
		address shareToken_,
		int256[7] calldata coreParams,
		int256[5] calldata riskParams,
		int256[5] calldata minRiskParamValues,
		int256[5] calldata maxRiskParamValues
	) internal {
		_core.operator = operator;
		_core.oracle = oracle;
		_core.factory = msg.sender;
		_core.vault = IFactory(_core.factory).vault();
		_core.vaultFeeRate = IFactory(_core.factory).vaultFeeRate();

		_core.initialMarginRate = coreParams[0];
		_core.maintenanceMarginRate = coreParams[1];
		_core.operatorFeeRate = coreParams[2];
		_core.lpFeeRate = coreParams[3];
		_core.referrerRebateRate = coreParams[4];
		_core.liquidationPenaltyRate = coreParams[5];
		_core.keeperGasReward = coreParams[6];
		_core.isCoreParameterValid();

		_core.halfSpreadRate.updateOption(
			riskParams[0],
			minRiskParamValues[0],
			maxRiskParamValues[0]
		);
		_core.beta1.updateOption(riskParams[1], minRiskParamValues[1], maxRiskParamValues[1]);
		_core.beta2.updateOption(riskParams[2], minRiskParamValues[2], maxRiskParamValues[2]);
		_core.fundingRateCoefficient.updateOption(
			riskParams[3],
			minRiskParamValues[3],
			maxRiskParamValues[3]
		);
		_core.targetLeverage.updateOption(
			riskParams[4],
			minRiskParamValues[4],
			maxRiskParamValues[4]
		);
		_core.isRiskParameterValid();

		_governor = governor_;
		_shareToken = shareToken_;
	}

	function governor() public view returns (address) {
		return _governor;
	}

	function shareToken() public view returns (address) {
		return _shareToken;
	}

	function information()
		public
		view
		returns (
			string memory underlyingAsset,
			address collateral,
			address factory,
			address oracle,
			address operator,
			address vault,
			int256[8] memory coreParameter,
			int256[5] memory riskParameter
		)
	{
		underlyingAsset = IOracle(_core.oracle).underlyingAsset();
		collateral = IOracle(_core.oracle).collateral();
		factory = _core.factory;
		oracle = _core.oracle;
		operator = _core.operator;
		vault = _core.vault;
		coreParameter = [
			_core.initialMarginRate,
			_core.maintenanceMarginRate,
			_core.operatorFeeRate,
			_core.vaultFeeRate,
			_core.lpFeeRate,
			_core.referrerRebateRate,
			_core.liquidationPenaltyRate,
			_core.keeperGasReward
		];
		riskParameter = [
			_core.halfSpreadRate.value,
			_core.beta1.value,
			_core.beta2.value,
			_core.fundingRateCoefficient.value,
			_core.targetLeverage.value
		];
	}

	function state()
		public
		syncState
		returns (
			bool isEmergency,
			bool isShuttingdown,
			int256 insuranceFund,
			int256 donatedInsuranceFund,
			int256 markPrice,
			int256 indexPrice
		)
	{
		isEmergency = _core.emergency;
		isShuttingdown = _core.shuttingdown;
		insuranceFund = _core.insuranceFund;
		donatedInsuranceFund = _core.donatedInsuranceFund;
		markPrice = _core.markPrice();
		indexPrice = _core.indexPrice();
	}

	function fundingState()
		public
		syncState
		returns (
			int256 unitAccumulativeFunding,
			int256 fundingRate,
			uint256 fundingTime
		)
	{
		unitAccumulativeFunding = _core.unitAccumulativeFunding;
		fundingRate = _core.fundingRate;
		fundingTime = _core.fundingTime;
	}

	bytes[50] private __gap;
}
