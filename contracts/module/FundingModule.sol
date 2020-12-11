// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

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
    using MarginModule for Market;
    using OracleModule for Market;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core, uint256 currentTime) public {
        if (core.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = currentTime.sub(core.fundingTime).toInt256();
        uint256 length = core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingState(core.markets[i], timeElapsed);
        }
        core.fundingTime = currentTime;
    }

    function updateFundingState(Market storage market, int256 timeElapsed) public {
        int256 deltaUnitLoss = market.indexPrice().wfrac(
            market.fundingRate.wmul(timeElapsed),
            FUNDING_INTERVAL
        );
        market.unitAccumulativeFunding = market.unitAccumulativeFunding.add(deltaUnitLoss);
    }

    function updateFundingRate(Core storage core) public {
        AMMModule.Context memory context = core.prepareContext();
        int256 poolMargin = AMMModule.isAMMMarginSafe(context, 0)
            ? AMMModule.regress(context, 0)
            : 0;
        uint256 length = core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingRate(core.markets[i], poolMargin);
        }
    }

    function updateFundingRate(Market storage market, int256 poolMargin) public {
        int256 newFundingRate;
        int256 positionAmount = market.positionAmount(address(this));
        if (positionAmount == 0) {
            newFundingRate = 0;
        } else {
            if (poolMargin != 0) {
                newFundingRate = market.indexPrice().wfrac(positionAmount, poolMargin).neg().wmul(
                    market.fundingRateCoefficient.value
                );
            } else if (positionAmount > 0) {
                newFundingRate = market.fundingRateCoefficient.value.neg();
            } else {
                newFundingRate = market.fundingRateCoefficient.value;
            }
        }
        market.fundingRate = newFundingRate;
    }
}
