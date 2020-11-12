// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../Type.sol";
import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMCommon.sol";

library AMMFunding {

    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeMath for uint256;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(
        FundingState storage fundingState,
        RiskParameter storage riskParameter,
        MarginAccount storage ammAccount,
        int256 indexPrice,
        uint256 indexPriceTimestamp,
        uint256 checkTimestamp
    ) internal {
        int256 tmpFundingRate;
        int256 deltaUnitAccFundingLoss;
        int256 tmpUnitAccFundingLoss = fundingState.unitAccFundingLoss;
        // lastFundingTime => price time
        if (indexPriceTimestamp > fundingState.lastFundingTime) {
            deltaUnitAccFundingLoss = calculateDeltaFundingLoss(
                fundingState.fundingRate,
                fundingState.lastIndexPrice,
                fundingState.lastFundingTime,
                indexPriceTimestamp
            );
            tmpUnitAccFundingLoss = tmpUnitAccFundingLoss.add(deltaUnitAccFundingLoss);
            tmpFundingRate = calculateFundingRate(
                fundingState,
                riskParameter,
                ammAccount,
                fundingState.lastIndexPrice
            );
        }
        // price time => now
        deltaUnitAccFundingLoss = calculateDeltaFundingLoss(
            tmpFundingRate,
            indexPrice,
            indexPriceTimestamp,
            checkTimestamp
        );
        tmpUnitAccFundingLoss = tmpUnitAccFundingLoss.add(deltaUnitAccFundingLoss);
        tmpFundingRate = calculateFundingRate(
            fundingState,
            riskParameter,
            ammAccount,
            indexPrice
        );
        fundingState.lastIndexPrice = indexPrice;
        fundingState.lastFundingTime = checkTimestamp;
        fundingState.fundingRate = tmpFundingRate;
        fundingState.unitAccFundingLoss = tmpUnitAccFundingLoss;
    }

    function updateFundingRate(
        FundingState storage fundingState,
        RiskParameter storage riskParameter,
        MarginAccount storage ammAccount,
        int256 indexPrice
    ) internal {
        int256 newFundingRate = calculateFundingRate(fundingState, riskParameter, ammAccount, indexPrice);
        fundingState.fundingRate = newFundingRate;
    }

    function calculateDeltaFundingLoss(
        int256 fundingRate,
        int256 indexPrice,
        uint256 beginTimestamp,
        uint256 endTimestamp
    ) internal pure returns (int256 deltaUnitAccumulatedFundingLoss) {
        require(endTimestamp > beginTimestamp, "time steps (n) must be positive");
        int256 timeElapsed = int256(endTimestamp.sub(beginTimestamp));
        deltaUnitAccumulatedFundingLoss = indexPrice
            .wfrac(fundingRate.wmul(timeElapsed), FUNDING_INTERVAL);
    }

    function calculateFundingRate(
        FundingState storage fundingState,
        RiskParameter storage riskParameter,
        MarginAccount storage ammAccount,
        int256 indexPrice
    ) internal view returns (int256 newFundingRate) {
        if (ammAccount.positionAmount == 0) {
            newFundingRate = 0;
        } else {
            int256 mc = AMMCommon.calculateCashBalance(ammAccount, fundingState.unitAccFundingLoss);
            ( int256 mv, int256 m0 ) = AMMCommon.regress(
                mc,
                ammAccount.positionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                riskParameter.beta1.value
            );
            if (ammAccount.positionAmount > 0) {
                newFundingRate = mc.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
            } else {
                newFundingRate = indexPrice.neg().wfrac(ammAccount.positionAmount, m0);
            }
            newFundingRate = newFundingRate.wmul(riskParameter.fundingRateCoefficent.value);
        }
    }

}
