// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../Type.sol";

library FeeModule {
	using SafeMathExt for int256;
	using SignedSafeMath for int256;

	function increaseClaimableFee(
		Core storage core,
		address claimer,
		int256 amount
	) internal {
		if (amount == 0) {
			return;
		}
		core.claimableFee[claimer] = core.claimableFee[claimer].add(amount);
		core.totalFee = core.totalFee.add(amount);
	}

	function claimFee(
		Core storage core,
		address claimer,
		int256 amount
	) internal {
		require(core.claimableFee[claimer].sub(amount) >= 0, "");
		core.claimableFee[claimer] = core.claimableFee[claimer].sub(amount);
		core.totalFee = core.totalFee.sub(amount);
	}
}
