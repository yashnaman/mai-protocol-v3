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
import "./MarginModule.sol";

library AMMModule {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeMath for uint256;
    using MarginModule for MarginAccount;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function calculateNextFundingState(
        FundingState storage fundingState,
        Settings storage settings,
        MarginAccount storage ammAccount,
        OraclePrice memory oracleData,
        uint256 currentTimestamp
    ) internal view returns (int256 newUnitAccumulatedFundingLoss, int256 newFundingRate) {
        int256 unitLoss;
        newUnitAccumulatedFundingLoss = fundingState.unitAccumulatedFundingLoss;
        // lastFundingTime => price time
        if (oracleData.timestamp > fundingState.lastFundingTime) {
            unitLoss = _calculateDeltaFundingLoss(
                fundingState.lastIndexPrice,
                fundingState.fundingRate,
                fundingState.lastFundingTime,
                oracleData.timestamp
            );
            newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);
            newFundingRate = calculateNextFundingRate(
                fundingState,
                settings,
                ammAccount,
                fundingState.lastIndexPrice
            );
        }
        // price time => now
        unitLoss = _calculateDeltaFundingLoss(
            oracleData.price,
            newFundingRate,
            oracleData.timestamp,
            currentTimestamp
        );
        newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);
        newFundingRate = calculateNextFundingRate(
            fundingState,
            settings,
            ammAccount,
            oracleData.price
        );
    }

    function calculateNextFundingRate(
        FundingState storage fundingState,
        Settings storage settings,
        MarginAccount storage ammAccount,
        int256 indexPrice
    ) internal view returns (int256 newFundingRate) {
        if (ammAccount.positionAmount == 0) {
            newFundingRate = 0;
        } else {
            int256 availableCashBalance = ammAccount.availableCashBalance(fundingState.unitAccumulatedFundingLoss);
            (
                int256 mv,
                int256 m0
            ) = regress(
                indexPrice,
                settings.targetLeverage,
                availableCashBalance,
                ammAccount.positionAmount,
                settings.beta1
            );
            if (ammAccount.positionAmount > 0) {
                newFundingRate = availableCashBalance.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
            } else {
                newFundingRate = indexPrice.neg().wfrac(ammAccount.positionAmount, m0);
            }
            return newFundingRate.wmul(settings.baseFundingRate);
        }
    }

    function calculateDeltaMargin(
        FundingState storage fundingState,
        Settings storage settings,
        MarginAccount storage ammAccount,
        int256 indexPrice,
        int256 tradingAmount
    ) internal view returns (int256 deltaMargin, int256 newCashBalance) {
        require(tradingAmount != 0, "no zero trade amount");
        int256 cashBalance = ammAccount.availableCashBalance(fundingState.unitAccumulatedFundingLoss);
        int256 positionAmount = ammAccount.positionAmount;
        (
            int256 closingAmount,
            int256 openingAmount
        ) = Utils.splitAmount(positionAmount, tradingAmount);
        deltaMargin = deltaMargin.add(
            close(settings, indexPrice, cashBalance, positionAmount, closingAmount)
        );
        deltaMargin = deltaMargin.add(
            open(settings, indexPrice, cashBalance.add(deltaMargin), positionAmount.add(closingAmount), openingAmount)
        );
        if (deltaMargin > 0) {
            // (1+a)*(1+b)-1=a+b+a*b
            deltaMargin = deltaMargin.wmul(Constant.SIGNED_ONE.add(settings.halfSpreadRate));
        } else {
            // 1-(1-a)*(1-b)=a+b-a*b
            deltaMargin = deltaMargin.wmul(Constant.SIGNED_ONE.sub(settings.halfSpreadRate));
        }
        int256 fee = settings.halfSpreadRate
            .add(settings.liquidityProviderFeeRate)
            .add(settings.halfSpreadRate.wmul(settings.liquidityProviderFeeRate))
            .wmul(deltaMargin);
        newCashBalance = cashBalance.add(fee.abs());
    }

    function _calculateDeltaFundingLoss(
        int256 indexPrice,
        int256 fundingRate,
        uint256 beginTimestamp,
        uint256 endTimestamp
    ) internal pure returns (int256 deltaUnitAccumulatedFundingLoss) {
        require(endTimestamp > beginTimestamp, "time steps (n) must be positive");
        int256 timeElapsed = int256(endTimestamp.sub(beginTimestamp));
        deltaUnitAccumulatedFundingLoss = indexPrice
            .wfrac(fundingRate.wmul(timeElapsed), FUNDING_INTERVAL);
    }

    function regress(
        int256 indexPrice,
        int256 targetLeverage,
        int256 cashBalance,
        int256 positionAmount,
        int256 beta
    ) internal pure returns (int256 mv, int256 m0) {
        if (positionAmount == 0) {
            mv = targetLeverage.sub(Constant.SIGNED_ONE).wmul(cashBalance);
        } else if (positionAmount > 0) {
            mv = positiveVirtualMargin(indexPrice, targetLeverage, cashBalance, positionAmount, beta);
        } else {
            mv = negativeVirtualMargin(indexPrice, targetLeverage, cashBalance, positionAmount, beta);
        }
        m0 = mv.wfrac(targetLeverage, targetLeverage.sub(Constant.SIGNED_ONE));
    }

    function positiveVirtualMargin(
        int256 indexPrice,
        int256 targetLeverage,
        int256 cashBalance,
        int256 positionAmount,
        int256 beta
    ) internal pure returns (int256 mv) {
        int256 t = targetLeverage.sub(Constant.SIGNED_ONE);
        int256 b = t.wmul(indexPrice.wmul(positionAmount)).add(targetLeverage.wmul(cashBalance));
        int256 beforeSqrt = beta.wmul(indexPrice).wmul(targetLeverage.wmul(cashBalance)).mul(positionAmount).mul(4);
        beforeSqrt = beforeSqrt.add(b.mul(b));
        mv = beta.sub(Constant.SIGNED_ONE).wmul(cashBalance).mul(2);
        mv = mv.add(beforeSqrt.sqrt()).add(b);
        mv = mv.wfrac(t, t.add(beta)).div(2);
    }

    function negativeVirtualMargin(
        int256 indexPrice,
        int256 targetLeverage,
        int256 cashBalance,
        int256 positionAmount,
        int256 beta
    ) internal pure returns (int256 mv) {
        int256 a = indexPrice.wmul(positionAmount).mul(2);
        int256 b = targetLeverage
            .add(Constant.SIGNED_ONE)
            .wmul(indexPrice.wmul(positionAmount))
            .add(targetLeverage.wmul(cashBalance));
        int256 beforeSqrt = b.mul(b).sub(beta.wmul(targetLeverage).wmul(a).mul(a));
        mv = b.sub(a).add(beforeSqrt.sqrt());
        mv = mv.wfrac(targetLeverage.sub(Constant.SIGNED_ONE), targetLeverage).div(2);
    }

    function open(
        Settings storage settings,
        int256 indexPrice,
        int256 cashBalance,
        int256 positionAmount,
        int256 tradingAmount
    ) internal view returns (int256 deltaMargin) {
        if (tradingAmount == 0) {
            return 0;
        }
        require(
            _isAMMMarginSafe(indexPrice, cashBalance, positionAmount, settings.targetLeverage, settings.beta1),
            "unsafe before trade"
        );
        ( int256 mv, int256 m0 )
            = regress(indexPrice, settings.targetLeverage, cashBalance, positionAmount, settings.beta1);
        if (positionAmount > 0 || (positionAmount == 0 && tradingAmount > 0)) {
            deltaMargin = longDeltaMargin(
                m0,
                cashBalance.add(mv),
                positionAmount,
                positionAmount.add(tradingAmount),
                settings.beta1,
                indexPrice
            );
        } else {
            deltaMargin = shortDeltaMargin(
                m0,
                positionAmount,
                positionAmount.add(tradingAmount),
                settings.beta1,
                indexPrice
            );
        }
        int256 newCashBalance = cashBalance.add(deltaMargin);
        int256 newPositionAmount = positionAmount.add(tradingAmount);
        require(
            _isAMMMarginSafe(indexPrice, newCashBalance, newPositionAmount, settings.targetLeverage, settings.beta1),
            "unsafe before trade"
        );
        (int256 newMV, ) = regress(
            indexPrice,
            settings.targetLeverage,
            newCashBalance,
            newPositionAmount,
            settings.beta1
        );
        require(newMV == mv, "unsafe after trade (origin margin change)");
    }

    function close(
        Settings storage settings,
        int256 indexPrice,
        int256 cashBalance,
        int256 positionAmount,
        int256 tradingAmount
    ) internal view returns (int256 deltaMargin) {
        require(positionAmount != 0, "zero position before close");
        if (tradingAmount == 0) {
            return 0;
        }
        if (_isAMMMarginSafe(indexPrice, cashBalance, positionAmount, settings.targetLeverage, settings.beta2)) {
            ( int256 mv, int256 m0 )
                = regress(indexPrice, settings.targetLeverage, cashBalance, positionAmount, settings.beta2);
            if (positionAmount > 0) {
                deltaMargin = longDeltaMargin(
                    m0,
                    cashBalance.add(mv),
                    positionAmount,
                    positionAmount.add(tradingAmount),
                    settings.beta2,
                    indexPrice
                );
            } else {
                deltaMargin = shortDeltaMargin(
                    m0,
                    positionAmount,
                    positionAmount.add(tradingAmount),
                    settings.beta2,
                    indexPrice
                );
            }
        } else {
            deltaMargin = indexPrice.wmul(tradingAmount);
        }
    }

    function longDeltaMargin(
        int256 originMargin,
        int256 availableMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 beta,
        int256 indexPrice
    ) public pure returns (int256 deltaMargin) {
        int256 a = Constant.SIGNED_ONE.sub(beta).wmul(availableMargin).mul(2);
        int256 b = positionAmount2.sub(positionAmount1).wmul(indexPrice);
        b = a.div(2).sub(b).wmul(availableMargin);
        b = b.sub(beta.wmul(originMargin).wmul(originMargin));
        int256 beforeSqrt = beta.wmul(a).wmul(availableMargin).wmul(originMargin).mul(originMargin).mul(2);
        beforeSqrt = beforeSqrt.add(b.mul(b));
        deltaMargin = beforeSqrt.sqrt().add(b).wdiv(a).sub(availableMargin);
    }

    function shortDeltaMargin(
        int256 originMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 beta,
        int256 indexPrice
    ) public pure returns (int256 deltaMargin) {
        deltaMargin = beta.wmul(originMargin).wmul(originMargin);
        deltaMargin = deltaMargin.wdiv(positionAmount1.wmul(indexPrice).add(originMargin));
        deltaMargin = deltaMargin.wdiv(positionAmount2.wmul(indexPrice).add(originMargin));
        deltaMargin = deltaMargin.add(Constant.SIGNED_ONE).sub(beta);
        deltaMargin = deltaMargin.wmul(indexPrice).wmul(positionAmount2.sub(positionAmount1)).neg();
    }

    function _isAMMMarginSafe(
        int256 indexPrice,
        int256 cashBalance,
        int256 positionAmount,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (bool) {
        if (positionAmount == 0 || (positionAmount > 0 && cashBalance < 0)) {
            return true;
        }
        if (positionAmount > 0) {
            return indexPrice >= _indexLowerbound(cashBalance, positionAmount, targetLeverage, beta);
        } else {
            return indexPrice <= _indexUpperbound(cashBalance, positionAmount, targetLeverage, beta);
        }
    }

    function _indexLowerbound(
        int256 cashBalance,
        int256 positionAmount,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 lowerbound) {
        int256 t = targetLeverage.sub(Constant.SIGNED_ONE);
        lowerbound = t.add(beta).mul(beta);
        lowerbound = lowerbound.sqrt().mul(2).add(t).add(beta.mul(2));
        lowerbound = lowerbound
            .wfrac(targetLeverage, positionAmount)
            .wfrac(cashBalance.neg(), t.wmul(t));
    }

    function _indexUpperbound(
        int256 cashBalance,
        int256 positionAmount,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 upperbound) {
        upperbound = beta.mul(targetLeverage).sqrt().mul(2).add(targetLeverage).add(Constant.SIGNED_ONE);
        upperbound = targetLeverage.wfrac(cashBalance, positionAmount.neg()).wdiv(upperbound);
    }

}
