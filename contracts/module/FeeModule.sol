// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../module/CollateralModule.sol";
import "../Type.sol";

library FeeModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using CollateralModule for Core;

    event ReceiveFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);

    function receiveFee(
        Core storage core,
        address recipient,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        core.claimableFees[recipient] = core.claimableFees[recipient].add(amount);
        core.totalClaimableFee = core.totalClaimableFee.add(amount);
        emit ReceiveFee(recipient, amount);
    }

    function claimFee(
        Core storage core,
        address claimer,
        int256 amount
    ) public {
        require(amount != 0, "zero amount");
        require(core.claimableFees[claimer].sub(amount) >= 0, "insufficient fee");
        core.claimableFees[claimer] = core.claimableFees[claimer].sub(amount);
        core.totalClaimableFee = core.totalClaimableFee.sub(amount);
        core.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }
}
