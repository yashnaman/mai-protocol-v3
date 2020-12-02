// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../libraries/SafeMathExt.sol";

import "../Type.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";
import "./AMMCommon.sol";

library FundingModule {
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using MarginModule for Core;
    using OracleModule for Core;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function updateFundingState(Core storage core, uint256 currentTime) public {
        if (core.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = int256(currentTime.sub(core.fundingTime));
        int256 deltaUnitLoss = core.indexPrice().wfrac(
            core.fundingRate.wmul(timeElapsed),
            FUNDING_INTERVAL
        );
        core.unitAccumulativeFunding = core.unitAccumulativeFunding.add(deltaUnitLoss);
        core.fundingTime = currentTime;
    }

    function updateFundingRate(Core storage core) public {
        core.fundingRate = nextFundingRate(core);
        core.fundingTime = block.timestamp;
    }

    function nextFundingRate(Core storage core) internal view returns (int256) {
        int256 positionAmount = core.marginAccounts[address(this)].positionAmount;
        if (positionAmount == 0) {
            return 0;
        }
        int256 indexPrice = core.indexPrice();
        int256 mc = core.availableCashBalance(address(this));
        if (
            AMMCommon.isAMMMarginSafe(
                mc,
                positionAmount,
                indexPrice,
                core.targetLeverage.value,
                core.beta1.value
            )
        ) {
            (int256 mv, int256 m0) = AMMCommon.regress(
                mc,
                positionAmount,
                indexPrice,
                core.targetLeverage.value,
                core.beta1.value
            );
            if (m0 != 0) {
                int256 fundingRate;
                if (positionAmount > 0) {
                    fundingRate = mc.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
                } else {
                    fundingRate = indexPrice.wfrac(positionAmount, m0).neg();
                }
                return fundingRate.wmul(core.fundingRateCoefficient.value);
            }
        }
        if (positionAmount > 0) {
            return core.fundingRateCoefficient.value.neg();
        } else {
            return core.fundingRateCoefficient.value;
        }
    }
}
