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
    using AMMModule for LiquidityPoolStorage;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    event UpdateUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding);
    event UpdatePoolMargin(int256 poolMargin);

    function updateFundingState(LiquidityPoolStorage storage liquidityPool, uint256 currentTime)
        public
    {
        if (liquidityPool.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = currentTime.sub(liquidityPool.fundingTime).toInt256();
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingState(liquidityPool.perpetuals[i], timeElapsed);
        }
        liquidityPool.fundingTime = currentTime;
    }

    function updateFundingState(PerpetualStorage storage perpetual, int256 timeElapsed) public {
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        int256 deltaUnitLoss = perpetual.getIndexPrice().wfrac(
            perpetual.fundingRate.wmul(timeElapsed),
            FUNDING_INTERVAL
        );
        perpetual.unitAccumulativeFunding = perpetual.unitAccumulativeFunding.add(deltaUnitLoss);
        emit UpdateUnitAccumulativeFunding(perpetual.id, perpetual.unitAccumulativeFunding);
    }

    function updateFundingRate(LiquidityPoolStorage storage liquidityPool) public {
        AMMModule.Context memory context = liquidityPool.prepareContext();
        int256 poolMargin = AMMModule.isAMMMarginSafe(context, 0)
            ? AMMModule.regress(context, 0)
            : 0;
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            updateFundingRate(liquidityPool.perpetuals[i], poolMargin);
        }
        emit UpdatePoolMargin(poolMargin);
    }

    function updateFundingRate(PerpetualStorage storage perpetual, int256 poolMargin) public {
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
        int256 newFundingRate;
        int256 position = perpetual.getPosition(address(this));
        if (position == 0) {
            newFundingRate = 0;
        } else {
            int256 fundingRateLimit = perpetual.fundingRateLimit.value;
            if (poolMargin != 0) {
                newFundingRate = perpetual.getIndexPrice().wfrac(position, poolMargin).neg().wmul(
                    perpetual.fundingRateLimit.value
                );
                newFundingRate = newFundingRate > fundingRateLimit
                    ? fundingRateLimit
                    : newFundingRate;
                newFundingRate = newFundingRate < fundingRateLimit.neg()
                    ? fundingRateLimit.neg()
                    : newFundingRate;
            } else if (position > 0) {
                newFundingRate = fundingRateLimit.neg();
            } else {
                newFundingRate = fundingRateLimit;
            }
        }
        perpetual.fundingRate = newFundingRate;
    }
}
