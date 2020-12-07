// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../libraries/SafeMathExt.sol";

import "./AMMModule.sol";
import "./MarginModule.sol";
import "./OracleModule.sol";

import "../Type.sol";

library FundingModule {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for Core;
    using MarginModule for Market;
    using OracleModule for Market;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core, uint256 currentTime) public {
        uint256 count = core.marketIDs.length();
        for (uint256 i = 0; i < count; i++) {
            updateFundingState(core.markets[core.marketIDs.at(i)], currentTime);
        }
    }

    function updateFundingState(Market storage market, uint256 currentTime) public {
        if (market.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = int256(currentTime.sub(market.fundingTime));
        int256 deltaUnitLoss = market.indexPrice().wfrac(
            market.fundingRate.wmul(timeElapsed),
            FUNDING_INTERVAL
        );
        market.unitAccumulativeFunding = market.unitAccumulativeFunding.add(deltaUnitLoss);
        market.fundingTime = currentTime;
    }

    function updateFundingRate(Core storage core) public {
        uint256 count = core.marketIDs.length();
        for (uint256 i = 0; i < count; i++) {
            Market storage market = core.markets[core.marketIDs.at(i)];
            market.fundingRate = nextFundingRate(core, market);
        }
    }

    function nextFundingRate(Core storage core, Market storage market)
        public
        view
        returns (int256)
    {
        AMMModule.Context memory context = core.prepareContext(market);
        if (context.positionAmount == 0) {
            return 0;
        }
        if (AMMModule.isAMMMarginSafe(context, market.openSlippage.value)) {
            int256 poolMargin = AMMModule.regress(context, market.openSlippage.value);
            if (poolMargin != 0) {
                return
                    context.indexPrice.wfrac(context.positionAmount, poolMargin).neg().wmul(
                        market.fundingRateCoefficient.value
                    );
            }
        }
        if (context.positionAmount > 0) {
            return market.fundingRateCoefficient.value.neg();
        } else {
            return market.fundingRateCoefficient.value;
        }
    }
}
