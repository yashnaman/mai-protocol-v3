// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";

import "./AMMModule.sol";
import "./MarginModule.sol";
import "./OracleModule.sol";

import "../Type.sol";

library FundingModule {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for Core;
    using MarginModule for Perpetual;
    using OracleModule for Perpetual;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core, uint256 currentTime) public {
        if (core.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = currentTime.sub(core.fundingTime).toInt256();
        uint256 length = core.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingState(core.perpetuals[i], timeElapsed);
        }
        core.fundingTime = currentTime;
    }

    function updateFundingState(Perpetual storage perpetual, int256 timeElapsed) public {
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        int256 deltaUnitLoss = perpetual.indexPrice().wfrac(
            perpetual.fundingRate.wmul(timeElapsed),
            FUNDING_INTERVAL
        );
        perpetual.unitAccumulativeFunding = perpetual.unitAccumulativeFunding.add(deltaUnitLoss);
    }

    function updateFundingRate(Core storage core) public {
        AMMModule.Context memory context = core.prepareContext();
        int256 poolMargin = AMMModule.isAMMMarginSafe(context, 0)
            ? AMMModule.regress(context, 0)
            : 0;
        uint256 length = core.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingRate(core.perpetuals[i], poolMargin);
        }
    }

    function updateFundingRate(Perpetual storage perpetual, int256 poolMargin) public {
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        int256 newFundingRate;
        int256 positionAmount = perpetual.positionAmount(address(this));
        if (positionAmount == 0) {
            newFundingRate = 0;
        } else {
            int256 fundingRateLimit = perpetual.fundingRateLimit.value;
            if (poolMargin != 0) {
                newFundingRate = perpetual
                    .indexPrice()
                    .wfrac(positionAmount, poolMargin)
                    .neg()
                    .wmul(perpetual.fundingRateLimit.value);
                newFundingRate = newFundingRate > fundingRateLimit
                    ? fundingRateLimit
                    : newFundingRate;
                newFundingRate = newFundingRate < fundingRateLimit.neg()
                    ? fundingRateLimit.neg()
                    : newFundingRate;
            } else if (positionAmount > 0) {
                newFundingRate = fundingRateLimit.neg();
            } else {
                newFundingRate = fundingRateLimit;
            }
        }
        perpetual.fundingRate = newFundingRate;
    }
}
