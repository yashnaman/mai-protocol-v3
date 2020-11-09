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

    function determineDeltaFundingLoss(
        int256 indexPrice,
        int256 fundingRate,
        uint256 beginTimestamp,
        uint256 endTimestamp
    ) public pure returns (int256 deltaUnitAccumulatedFundingLoss) {
        require(endTimestamp > beginTimestamp, "time steps (n) must be positive");
        int256 timeElapsed = int256(endTimestamp.sub(beginTimestamp));
        deltaUnitAccumulatedFundingLoss = indexPrice
            .wfrac(fundingRate.wmul(timeElapsed), FUNDING_INTERVAL);
    }

    function calculateBaseFundingRate(
        Settings storage settings,
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice
    ) public view returns (int256 baseFundingRate) {
        if (positionAmount == 0) {
            baseFundingRate = 0;
        } else {
            ( int256 mv, int256 m0 )
                = regress(indexPrice, settings.targetLeverage, cashBalance, positionAmount, settings.beta1);
            if (positionAmount > 0) {
                baseFundingRate = cashBalance.add(mv).wdiv(m0).sub(Constant.SIGNED_ONE);
            } else {
                baseFundingRate = indexPrice.neg().wfrac(positionAmount, m0);
            }
            return baseFundingRate.wmul(settings.baseFundingRate);
        }
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

    function determineDeltaMargin(
        Settings storage settings,
        int256 indexPrice,
        int256 cashBalance,
        int256 positionAmount,
        int256 tradingAmount
    ) public view returns (int256 deltaMargin, int256 newCashBalance) {
        require(tradingAmount != 0, "no zero trade amount");

        (int256 closingAmount, int256 openingAmount) = Utils.splitAmount(positionAmount, tradingAmount);
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
            _isMarginSafe(indexPrice, cashBalance, positionAmount, settings.targetLeverage, settings.beta1),
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
            _isMarginSafe(indexPrice, newCashBalance, newPositionAmount, settings.targetLeverage, settings.beta1),
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
        if (_isMarginSafe(indexPrice, cashBalance, positionAmount, settings.targetLeverage, settings.beta2)) {
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

    function _isMarginSafe(
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


    // function addLiquidatity(
    //     Perpetual storage perpetual,
    //     MarginAccount memory account,
    //     int256 amount
    // ) public {
    //     require(amount > 0, "add amount must over 0");
    //     account.cashBalance = account.cashBalance.add(amount);
    // }

    // function removeLiquidatity(
    //     Perpetual storage perpetual,
    //     MarginAccount memory account,
    //     int256 amount
    // ) public {
    //     require(amount > 0, "remove amount must over 0");
    //     require(isSafe(perpetual, account, perpetual.settings.beta1), "unsafe before remove");
    //     MarginAccount memory afterRemoveAccount = account;
    //     afterRemoveAccount.cashBalance = afterRemoveAccount.cashBalance.sub(amount);
    //     require(isSafe(perpetual, afterRemoveAccount, perpetual.settings.beta1), "unsafe after remove");
    //     (, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
    //     (, int256 newOriginMargin) = regress(perpetual, afterRemoveAccount, perpetual.settings.beta1);
    //     int256 penalty = originMargin.sub(newOriginMargin).sub(perpetual.settings.targetLeverage.wmul(amount));
    //     if (penalty < 0) {
    //         penalty = 0;
    //     } else if (penalty > amount) {
    //         penalty = amount;
    //     }
    //     account.cashBalance = account.cashBalance.sub(amount.sub(penalty));
    // }

}
