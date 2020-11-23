// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./Events.sol";
import "./Storage.sol";
import "./Type.sol";

import "./module/ParameterModule.sol";
import "./module/StateModule.sol";

// @title Goovernance is the contract to maintain perpetual parameters.
contract Governance is Storage, Events {
	using SafeMath for uint256;
	using ParameterModule for Core;
	using StateModule for Core;

	modifier voteOnly() {
		require(msg.sender == _governor, "");
		_;
	}

	modifier operatorOnly() {
		require(msg.sender == _core.operator, "");
		_;
	}

	function updateCoreParameter(bytes32 key, int256 newValue) external voteOnly {
		_core.updateCoreParameter(key, newValue);
		emit UpdateCoreSetting(key, newValue);
	}

	function updateRiskParameter(
		bytes32 key,
		int256 newValue,
		int256 minValue,
		int256 maxValue
	) external voteOnly {
		_core.updateRiskParameter(key, newValue, minValue, maxValue);
		emit UpdateRiskSetting(key, newValue, minValue, maxValue);
	}

	function adjustRiskParameter(bytes32 key, int256 newValue) external operatorOnly {
		_core.adjustRiskParameter(key, newValue);
		emit AdjustRiskSetting(key, newValue);
	}

	function shutdown() external {
		require(block.timestamp.sub(_core.indexPriceData.time) > 24 * 3600, "index price timeout");
		_core.enterEmergencyState();
	}

	bytes[50] private __gap;
}
