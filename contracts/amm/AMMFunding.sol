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
import "../Type.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";

library AMMFunding {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeMath for uint256;
    using MarginModule for Core;
    using OracleModule for Core;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core) public {
        uint256 fundingTime = block.timestamp;
        if (fundingTime > core.fundingTime) {
            int256 timeElapsed = int256(fundingTime.sub(core.fundingTime));
            int256 deltaUnitLoss = core.indexPrice().wfrac(
                core.fundingRate.wmul(timeElapsed),
                FUNDING_INTERVAL
            );
            core.unitAccumulatedFundingLoss = core
                .unitAccumulatedFundingLoss
                .add(deltaUnitLoss);
            core.fundingTime = fundingTime;
        }
    }

    function updateFundingRate(Core storage core) public {
        int256 positionAmount = core.marginAccounts[address(this)]
            .positionAmount;
        if (positionAmount == 0) {
            core.fundingRate = 0;
            return;
        }
        int256 mc = core.cashBalance(address(this));
        require(
            AMMCommon.isAMMMarginSafe(
                mc,
                positionAmount,
                core.indexPrice(),
                core.targetLeverage.value,
                core.beta1.value
            ),
            "amm unsafe"
        );
        (int256 mv, int256 m0) = AMMCommon.regress(
            mc,
            positionAmount,
            core.indexPrice(),
            core.targetLeverage.value,
            core.beta1.value
        );
        int256 fundingRate;
        if (positionAmount > 0) {
            fundingRate = mc.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
        } else {
            fundingRate = core.indexPrice().neg().wfrac(positionAmount, m0);
        }
        core.fundingRate = fundingRate.wmul(core.fundingRateCoefficient.value);
        return;
    }
}
