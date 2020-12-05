// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../libraries/SafeMathExt.sol";

import "./AMMCommon.sol";
import "./MarginModule.sol";
import "./OracleModule.sol";

import "../Type.sol";

library FundingModule {
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using MarginModule for Market;
    using OracleModule for Market;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core, uint256 currentTime) public {
        uint256 count = core.markets.length;
        for (uint256 i = 0; i < count; i++) {
            updateFundingState(core.markets[i], currentTime);
        }
    }

    function updateFundingRate(Core storage core) public {
        uint256 count = core.markets.length;
        for (uint256 i = 0; i < count; i++) {
            updateFundingRate(core.markets[i]);
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

    function updateFundingRate(Market storage market) public {
        market.fundingRate = nextFundingRate(market);
    }

    function nextFundingRate(Market storage market) public view returns (int256) {
        int256 positionAmount = market.positionAmount(address(this));
        if (positionAmount == 0) {
            return 0;
        }
        int256 indexPrice = market.indexPrice();
        int256 mc = market.availableCashBalance(address(this));
        if (
            AMMCommon.isAMMMarginSafe(
                mc,
                positionAmount,
                indexPrice,
                market.maxLeverage.value,
                market.openSlippage.value
            )
        ) {
            (int256 mv, int256 m0) = AMMCommon.regress(
                mc,
                positionAmount,
                indexPrice,
                market.maxLeverage.value,
                market.openSlippage.value
            );
            if (m0 != 0) {
                int256 fundingRate;
                if (positionAmount > 0) {
                    fundingRate = mc.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
                } else {
                    fundingRate = indexPrice.wfrac(positionAmount, m0).neg();
                }
                return fundingRate.wmul(market.fundingRateCoefficient.value);
            }
        }
        if (positionAmount > 0) {
            return market.fundingRateCoefficient.value.neg();
        } else {
            return market.fundingRateCoefficient.value;
        }
    }
}
