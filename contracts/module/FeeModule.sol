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
        core.claimableFees[claimer] = core.claimableFees[claimer].add(amount);
        core.totalClaimableFee = core.totalClaimableFee.add(amount);
    }

    function claimFee(
        Core storage core,
        address claimer,
        int256 amount
    ) internal {
        require(core.claimableFees[claimer].sub(amount) >= 0, "");
        core.claimableFees[claimer] = core.claimableFees[claimer].sub(amount);
        core.totalClaimableFee = core.totalClaimableFee.sub(amount);
    }
}
