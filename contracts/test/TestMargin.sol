// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginModule.sol";
import "../module/ParameterModule.sol";
import "../Storage.sol";

contract TestMargin is Storage {
	using MarginModule for Core;
	using ParameterModule for Core;

	function updateMarkPrice(int256 price) external {
		_core.markPriceData.price = price;
	}

	function updateMarginAccount(
		address trader,
		int256 cashBalance,
		int256 positionAmount,
		int256 entryFunding
	) external {
		_core.marginAccounts[trader].cashBalance = cashBalance;
		_core.marginAccounts[trader].positionAmount = positionAmount;
		_core.marginAccounts[trader].entryFunding = entryFunding;
	}

	function updateUnitAccumulativeFunding(int256 newUnitAccumulativeFunding) external {
		_core.unitAccumulativeFunding = newUnitAccumulativeFunding;
	}

	function updateCoreParameter(bytes32 key, int256 newValue) external {
		_core.updateCoreParameter(key, newValue);
	}

	function initialMargin(address trader) external view returns (int256) {
		return _core.initialMargin(trader);
	}

	function maintenanceMargin(address trader) external view returns (int256) {
		return _core.maintenanceMargin(trader);
	}

	function availableCashBalance(address trader) external view returns (int256) {
		return _core.availableCashBalance(trader);
	}

	function margin(address trader) external view returns (int256) {
		return _core.margin(trader);
	}

	function availableMargin(address trader) external view returns (int256) {
		return _core.availableMargin(trader);
	}

	function isInitialMarginSafe(address trader) external view returns (bool) {
		return _core.isInitialMarginSafe(trader);
	}

	function isMaintenanceMarginSafe(address trader) external view returns (bool) {
		return _core.isMaintenanceMarginSafe(trader);
	}
}
