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

    uint256 constant FUNDING_INTERVAL = 3600 * 8;

    function nextStateWithTimespan(
        FundingState storage fundingState,
        int256 price,
        uint256 endTimestamp
    ) internal {
        require(endTimestamp >= fundingState.lastFundingTime, "time steps (n) must be positive");
        if (fundingState.lastFundingTime != endTimestamp) {
            int256 timeDelta = endTimestamp.sub(fundingState.lastFundingTime).toInt256();
            fundingState.unitAccumulatedFundingLoss = fundingState.lastIndexPrice
                .wmul(timeDelta)
                .wmul(fundingState.lastFundingRate)
                .div(FUNDING_INTERVAL)
                .add(fundingState.unitAccumulatedFundingLoss);
            fundingState.lastFundingTime = endTimestamp;
        }
        // always update
        perpetual.state.lastIndexPrice = price; // should update before calculate funding rate()
        perpetual.state.lastFundingRate = fundingRate(perpetual, account);
    }

    function determineDeltaFundingLoss(
        int256 price,
        int256 fundingRate,
        uint256 beginTimestamp,
        uint256 endTimestamp
    ) public pure returns (int256 deltaUnitAccumulatedFundingLoss) {
        require(endTimestamp > beginTimestamp, "time steps (n) must be positive");
        int256 timeElapsed = int256(endTimestamp.sub(beginTimestamp));
        deltaUnitAccumulatedFundingLoss = price
            .wfrac(fundingRate.wmul(timeDelta), FUNDING_INTERVAL);
    }

    function fundingRate(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256 fundingRate) {
        (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
        if (account.positionAmount == 0) {
            fundingRate = 0;
        } else if (account.positionAmount > 0) {
            fundingRate = perpetual.availableCashBalance(account).add(virtualMargin).wdiv(originMargin).sub(Constant.SIGNED_ONE).wmul(perpetual.settings.baseFundingRate);
        } else {
            fundingRate = perpetual.state.indexPrice.neg().wmul(account.positionAmount).wdiv(originMargin).wmul(perpetual.settings.baseFundingRate);
        }
    }

    function funding(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) internal {
        uint256 blockTime = getBlockTimestamp();
        (int256 newIndexPrice, uint256 newIndexTimestamp) = indexPrice();
        if (
            blockTime != perpetual.state.lastFundingTime ||
            newIndexPrice != perpetual.state.lastIndexPrice ||
            newIndexTimestamp > perpetual.state.lastFundingTime
        ) {
            forceFunding(perpetual, account, blockTime, newIndexPrice, newIndexTimestamp);
        }
    }

    function forceFunding(
        Perpetual storage perpetual,
        MarginAccount memory account,
        uint256 blockTime,
        int256 newIndexPrice,
        uint256 newIndexTimestamp
    ) private {
        if (perpetual.state.lastFundingTime == 0) {
            // funding initialization required. but in this case, it's safe to just do nothing and return
            return;
        }
        if (newIndexTimestamp > perpetual.state.lastFundingTime) {
            // the 1st update
            nextStateWithTimespan(perpetual, account, newIndexPrice, newIndexTimestamp);
        }
        // the 2nd update;
        nextStateWithTimespan(perpetual, account, newIndexPrice, blockTime);
    }

    function nextStateWithTimespan(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 newIndexPrice,
        uint256 endTimestamp
    ) private {
        require(perpetual.state.lastFundingTime != 0, "funding initialization required");
        require(endTimestamp >= perpetual.state.lastFundingTime, "time steps (n) must be positive");

        if (perpetual.state.lastFundingTime != endTimestamp) {
            int256 timeDelta = endTimestamp.sub(perpetual.state.lastFundingTime).toInt256();
            perpetual.state.unitAccumulatedFundingLoss = perpetual.state.unitAccumulatedFundingLoss.add(perpetual.state.lastIndexPrice.wmul(timeDelta).wmul(perpetual.state.lastFundingRate).div(28800));
            perpetual.state.lastFundingTime = endTimestamp;
        }

        // always update
        perpetual.state.lastIndexPrice = newIndexPrice; // should update before calculate funding rate()
        perpetual.state.lastFundingRate = fundingRate(perpetual, account);
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
            (
                int256 virtualMargin,
                int256 originMargin
            ) = regress(indexPrice, targetLeverage, cashBalance, positionAmount, settings.beta1);
            if (positionAmount > 0) {
                baseFundingRate = cashBalance.add(virtualMargin).wdiv(originMargin).sub(Constant.SIGNED_ONE);
            } else {
                baseFundingRate = indexPrice.neg().wfrac(account.positionAmount, originMargin);
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
    ) public view returns (int256 virtualMargin, int256 originMargin) {
        int256 virtualLeverage = targetLeverage.sub(Constant.SIGNED_ONE);
        if (positionAmount == 0) {
            virtualMargin = virtualLeverage.wmul(cashBalance);
        } else {
            int256 indexValue = indexPrice.wmul(positionAmount);
            int256 targetValue = targetLeverage.wmul(cashBalance);
            if (positionAmount > 0) {
                int256 b = virtualLeverage.wmul(indexValue).add(targetValue);
                int256 beforeSqrt = beta.wmul(indexPrice).wmul(targetValue).mul(positionAmount).mul(4);
                beforeSqrt = beforeSqrt.add(b.mul(b));
                virtualMargin = beta.sub(Constant.SIGNED_ONE).wmul(cashBalance).mul(2);
                virtualMargin = virtualMargin.add(beforeSqrt.sqrt()).add(b);
                virtualMargin = virtualMargin.wfrac(virtualLeverage, virtualLeverage.add(beta)).div(2);
            } else {
                int256 a = indexValue.mul(2);
                int256 b = targetLeverage.add(Constant.SIGNED_ONE).wmul(indexValue).add(targetValue);
                int256 beforeSqrt = b.mul(b).sub(beta.wmul(targetLeverage).wmul(a).mul(a));
                virtualMargin = b.sub(a).add(beforeSqrt.sqrt());
                virtualMargin = virtualMargin.wfrac(virtualLeverage, targetLeverage).div(2);
            }
        }
        originMargin = virtualMargin.frac(targetLeverage, virtualLeverage);
    }


    function determineDeltaMargin(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount
    ) public view returns (int256 deltaMargin) {
        require(tradeAmount != 0, "no zero trade amount");
        (int256 closeAmount, int256 openAmount) = Utils.splitAmount(account.positionAmount, tradeAmount);
        deltaMargin = deltaMargin.add(close(perpetual, account, closeAmount));
        deltaMargin = deltaMargin.add(open(perpetual, account, openAmount));
        int256 halfSpreadRate = perpetual.settings.halfSpreadRate;
        int256 liquidityProviderFeeRate = perpetual.settings.liquidityProviderFeeRate;
        if (deltaMargin > 0) {
            // (1+a)*(1+b)-1=a+b+a*b
            account.cashBalance = account.cashBalance.add(halfSpreadRate.add(liquidityProviderFeeRate).add(halfSpreadRate.wmul(liquidityProviderFeeRate)).wmul(deltaMargin));
            deltaMargin = deltaMargin.wmul(Constant.SIGNED_ONE.add(halfSpreadRate));
        } else {
            // 1-(1-a)*(1-b)=a+b-a*b
            account.cashBalance = account.cashBalance.sub(halfSpreadRate.add(liquidityProviderFeeRate).sub(halfSpreadRate.wmul(liquidityProviderFeeRate)).wmul(deltaMargin));
            deltaMargin = deltaMargin.wmul(Constant.SIGNED_ONE.sub(halfSpreadRate));
        }
    }

    function open(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount
    ) internal view returns (int256 deltaMargin) {
        if (tradeAmount == 0) {
            return 0;
        }
        require(isSafe(perpetual, account, perpetual.settings.beta1), "unsafe before trade");
        (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
        if (account.positionAmount > 0 || (account.positionAmount == 0 && tradeAmount > 0)) {
            deltaMargin = longDeltaMargin(originMargin, perpetual.availableCashBalance(account).add(virtualMargin), account.positionAmount, account.positionAmount.add(tradeAmount), perpetual.settings.beta1, perpetual.state.indexPrice);
        } else {
            deltaMargin = shortDeltaMargin(originMargin, account.positionAmount, account.positionAmount.add(tradeAmount), perpetual.settings.beta1, perpetual.state.indexPrice);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin);
        account.positionAmount = account.positionAmount.add(tradeAmount);
        require(isSafe(perpetual, account, perpetual.settings.beta1), "unsafe after trade");
        (int256 newVirtualMargin, ) = regress(perpetual, account, perpetual.settings.beta1);
        require(newVirtualMargin == virtualMargin, "unsafe after trade (origin margin change)");
    }

    function close(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount
    ) internal view returns (int256 deltaMargin) {
        if (tradeAmount == 0) {
            return 0;
        }
        require(account.positionAmount != 0, "zero position before close");
        if (isSafe(perpetual, account, perpetual.settings.beta2)) {
            (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta2);
            if (account.positionAmount > 0) {
                deltaMargin = longDeltaMargin(originMargin, perpetual.availableCashBalance(account).add(virtualMargin), account.positionAmount, account.positionAmount.add(tradeAmount), perpetual.settings.beta2, perpetual.state.indexPrice);
            } else {
                deltaMargin = shortDeltaMargin(originMargin, account.positionAmount, account.positionAmount.add(tradeAmount), perpetual.settings.beta2, perpetual.state.indexPrice);
            }
        } else {
            deltaMargin = perpetual.state.indexPrice.wmul(tradeAmount);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin);
        account.positionAmount = account.positionAmount.add(tradeAmount);
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

    function longIsSafe(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta
    ) public view returns (bool) {
        int256 availableCashBalance = perpetual.availableCashBalance(account);
        if (availableCashBalance < 0) {
            int256 targetLeverage = perpetual.settings.targetLeverage;
            int256 targetLeverageMinusOne = targetLeverage.sub(Constant.SIGNED_ONE);
            int256 minIndex = targetLeverageMinusOne.add(beta).mul(beta);
            minIndex = minIndex.sqrt().mul(2).add(targetLeverageMinusOne);
            minIndex = minIndex.add(beta.mul(2)).wmul(targetLeverage).wmul(availableCashBalance.neg());
            minIndex = minIndex.wdiv(account.positionAmount).wdiv(targetLeverageMinusOne).wdiv(targetLeverageMinusOne);
            return perpetual.state.indexPrice >= minIndex;
        } else {
            return true;
        }
    }

    function shortIsSafe(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta
    ) public view returns (bool) {
        int256 targetLeverage = perpetual.settings.targetLeverage;
        int256 maxIndex = beta.mul(targetLeverage).sqrt().mul(2).add(targetLeverage).add(Constant.SIGNED_ONE);
        maxIndex = targetLeverage.wmul(perpetual.availableCashBalance(account)).wdiv(account.positionAmount.neg()).wdiv(maxIndex);
        return perpetual.state.indexPrice <= maxIndex;
    }

    function isSafe(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta
    ) public view returns (bool) {
        if (account.positionAmount == 0) {
            return true;
        } else if (account.positionAmount > 0) {
            return longIsSafe(perpetual, account, beta);
        } else {
            return shortIsSafe(perpetual, account, beta);
        }
    }

    function addLiquidatity(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 amount
    ) public {
        require(amount > 0, "add amount must over 0");
        account.cashBalance = account.cashBalance.add(amount);
    }

    function removeLiquidatity(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 amount
    ) public {
        require(amount > 0, "remove amount must over 0");
        require(isSafe(perpetual, account, perpetual.settings.beta1), "unsafe before remove");
        MarginAccount memory afterRemoveAccount = account;
        afterRemoveAccount.cashBalance = afterRemoveAccount.cashBalance.sub(amount);
        require(isSafe(perpetual, afterRemoveAccount, perpetual.settings.beta1), "unsafe after remove");
        (, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
        (, int256 newOriginMargin) = regress(perpetual, afterRemoveAccount, perpetual.settings.beta1);
        int256 penalty = originMargin.sub(newOriginMargin).sub(perpetual.settings.targetLeverage.wmul(amount));
        if (penalty < 0) {
            penalty = 0;
        } else if (penalty > amount) {
            penalty = amount;
        }
        account.cashBalance = account.cashBalance.sub(amount.sub(penalty));
    }

}
