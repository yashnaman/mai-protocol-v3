// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../Type.sol";
import "../lib/LibConstant.sol";
import "../lib/LibMath.sol";
import "../lib/LibSafeMathExt.sol";
import "./MarginAccountImp.sol";

library AMMImp {
    using MarginAccountImp for Perpetual;
    using SignedSafeMath for int256;
    using LibSafeMathExt for int256;
    using SafeMath for uint256;
    using LibMath for int256;
    using LibMath for uint256;

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

    function fundingRate(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256 fundingRate) {
        (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
        if (account.positionAmount == 0) {
            fundingRate = 0;
        } else if (account.positionAmount > 0) {
            fundingRate = perpetual.availableCashBalance(account).add(virtualMargin).wdiv(originMargin).sub(LibConstant.SIGNED_ONE).wmul(perpetual.settings.baseFundingRate);
        } else {
            fundingRate = perpetual.state.indexPrice.neg().wmul(account.positionAmount).wdiv(originMargin).wmul(perpetual.settings.baseFundingRate);
        }
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    function indexPrice() public view returns (int256 price, uint256 timestamp) {
        // (price, timestamp) = priceFeeder.price();
        price = 1;
        timestamp = 1;
        require(price != 0, "dangerous index price");
    }

    function determineDeltaCashBalance(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount
    ) public returns (int256 deltaMargin) {
        require(tradeAmount != 0, "no zero trade amount");
        funding(perpetual, account);
        if (tradeAmount > 0) {
            if (account.positionAmount > 0) {
                if (tradeAmount > account.positionAmount) {
                    close(perpetual, account, account.positionAmount, Side.LONG);
                    open(perpetual, account, tradeAmount.sub(account.positionAmount), Side.SHORT);
                } else {
                    close(perpetual, account, tradeAmount, Side.LONG);
                }
            } else {
                open(perpetual, account, tradeAmount, Side.SHORT);
            }
        } else {
            if (account.positionAmount < 0) {
                if (tradeAmount < account.positionAmount) {
                    close(perpetual, account, account.positionAmount, Side.SHORT);
                    open(perpetual, account, tradeAmount.sub(account.positionAmount), Side.LONG);
                } else {
                    close(perpetual, account, tradeAmount, Side.SHORT);
                }
            } else {
                open(perpetual, account, tradeAmount, Side.LONG);
            }
        }
    }

    function open(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount,
        Side side
    ) internal view returns (int256 deltaMargin) {
        (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta1);
        if (account.positionAmount == 0 || isSafe(perpetual, account, perpetual.settings.beta1, side)) {
            if (side == Side.LONG) {
                deltaMargin = longDeltaMargin(originMargin, perpetual.availableCashBalance(account).add(virtualMargin), account.positionAmount, account.positionAmount.sub(tradeAmount), perpetual.settings.beta1, perpetual.state.indexPrice);
            } else {
                deltaMargin = shortDeltaMargin(originMargin, account.positionAmount, account.positionAmount.sub(tradeAmount), perpetual.settings.beta1, perpetual.state.indexPrice);
            }
            (int256 newVirtualMargin, ) = regress(perpetual, account, perpetual.settings.beta1);
            if (newVirtualMargin != virtualMargin) {
                revert("after trade unsafe(origin margin change)");
            }
            if (!isSafe(perpetual, account, perpetual.settings.beta1, side)) {
                revert("after trade unsafe");
            }
        } else {
            revert("before trade unsafe");
        }
    }

    function close(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 tradeAmount,
        Side side
    ) internal view returns (int256 deltaMargin) {
        require(account.positionAmount != 0, "zero position before close");
        (int256 virtualMargin, int256 originMargin) = regress(perpetual, account, perpetual.settings.beta2);
        if (isSafe(perpetual, account, perpetual.settings.beta2, side)) {
            if (side == Side.LONG) {
                deltaMargin = longDeltaMargin(originMargin, perpetual.availableCashBalance(account).add(virtualMargin), account.positionAmount, account.positionAmount.sub(tradeAmount), perpetual.settings.beta2, perpetual.state.indexPrice);
            } else {
                deltaMargin = shortDeltaMargin(originMargin, account.positionAmount, account.positionAmount.sub(tradeAmount), perpetual.settings.beta2, perpetual.state.indexPrice);
            }
        } else {
            deltaMargin = perpetual.state.indexPrice.wmul(tradeAmount);
        }
    }

    function regress(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta
    ) public view returns (int256 virtualMargin, int256 originMargin) {
        if (account.positionAmount == 0) {
            virtualMargin = perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(account.cashBalance);
        } else if (account.positionAmount > 0) {
            int256 b = perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(perpetual.state.indexPrice).wmul(account.positionAmount);
            b = b.add(perpetual.settings.targetLeverage.wmul(account.cashBalance));
            int256 beforeSqrt = beta.wmul(perpetual.state.indexPrice).wmul(perpetual.settings.targetLeverage).wmul(account.cashBalance).mul(account.positionAmount).mul(4);
            beforeSqrt = beforeSqrt.add(b.mul(b));
            virtualMargin = beta.sub(LibConstant.SIGNED_ONE).wmul(account.cashBalance).mul(2);
            virtualMargin = virtualMargin.add(beforeSqrt.sqrt()).add(b);
            virtualMargin = virtualMargin.wmul(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE));
            virtualMargin = virtualMargin.wdiv(perpetual.settings.targetLeverage.add(beta).sub(LibConstant.SIGNED_ONE)).div(2);
        } else {
            int256 a = perpetual.state.indexPrice.wmul(account.positionAmount).mul(2);
            int256 b = perpetual.settings.targetLeverage.add(LibConstant.SIGNED_ONE).wmul(perpetual.state.indexPrice).wmul(account.positionAmount);
            b = b.add(perpetual.settings.targetLeverage.wmul(account.cashBalance));
            int256 beforeSqrt = b.mul(b).sub(beta.wmul(perpetual.settings.targetLeverage).wmul(a).mul(a));
            virtualMargin = b.sub(a).add(beforeSqrt.sqrt());
            virtualMargin = virtualMargin.wmul(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE));
            virtualMargin = virtualMargin.wdiv(perpetual.settings.targetLeverage).div(2);
        }
        originMargin = virtualMargin.wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE)).wmul(perpetual.settings.targetLeverage);
    }

    function longDeltaMargin(
        int256 originMargin,
        int256 availableMargin,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 beta,
        int256 indexPrice
    ) public pure returns (int256 deltaMargin) {
        int256 a = LibConstant.SIGNED_ONE.sub(beta).wmul(availableMargin).mul(2);
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
        deltaMargin = deltaMargin.add(LibConstant.SIGNED_ONE).sub(beta);
        deltaMargin = deltaMargin.wmul(indexPrice).wmul(positionAmount2.sub(positionAmount1)).neg();
    }

    function longIsSafe(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta
    ) public view returns (bool) {
        require(account.positionAmount >= 0, "only for long");
        int256 availableCashBalance = perpetual.availableCashBalance(account);
        if (availableCashBalance < 0) {
            int256 targetLeverage = perpetual.settings.targetLeverage;
            int256 targetLeverageMinusOne = targetLeverage.sub(LibConstant.SIGNED_ONE);
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
        require(account.positionAmount <= 0, "only for short");
        int256 targetLeverage = perpetual.settings.targetLeverage;
        int256 maxIndex = beta.mul(targetLeverage).sqrt().mul(2).add(targetLeverage).add(LibConstant.SIGNED_ONE);
        maxIndex = targetLeverage.wmul(perpetual.availableCashBalance(account)).wdiv(account.positionAmount.neg()).wdiv(maxIndex);
        return perpetual.state.indexPrice <= maxIndex;
    }

    function isSafe(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 beta,
        Side side
    ) public view returns (bool) {
        if (side == Side.LONG) {
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
        account.cashBalance = account.cashBalance.add(amount);
    }

    function removeLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

}
