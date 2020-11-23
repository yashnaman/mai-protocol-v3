// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Type.sol";

library StateModule {
	function isNormal(Core storage core) internal view returns (bool) {
		return !core.emergency && !core.shuttingdown;
	}

	function isEmergency(Core storage core) internal view returns (bool) {
		return core.emergency;
	}

	function isShuttingDown(Core storage core) internal view returns (bool) {
		return core.emergency;
	}

	function enterEmergencyState(Core storage core) internal {
		require(isNormal(core), "");
		core.emergency = true;
	}

	function enterShuttingDownState(Core storage core) internal {
		require(isEmergency(core), "");
		core.emergency = false;
		core.shuttingdown = true;
	}
}
