// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Validator.sol";
import "../amm/AMMFunding.sol";
import "../Type.sol";

library FundingModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMFunding for Core;
    using Validator for Core;

    function updateFundingState(Core storage core) internal {
        if (core.fundingTime == 0) {
            return;
        }
        if (core.fundingTime != block.timestamp) {
            return;
        }
        core.updateFundingState();
    }

    function updateFundingRate(Core storage core) internal {
        core.updateFundingRate();
    }
}
