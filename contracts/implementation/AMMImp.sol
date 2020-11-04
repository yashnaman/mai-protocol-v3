// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../Type.sol";
import "../lib/LibConstant.sol";
import "../lib/LibMath.sol";
import "../lib/LibSafeMathExt.sol";

library AMMImp {
    using SignedSafeMath for int256;
    using LibSafeMathExt for int256;
    using SafeMath for uint256;
    using LibMath for int256;
    using LibMath for uint256;

    function updateFundingRate(
        Perpetual storage perpetual,
        Context memory context
    ) public view {
        // update funding rate.

    }

    function longSideTrade(
	Perpetual storage perpetual,
	MarginAccount memory account,
	int256 amount
    ) internal view returns (int256 deltaMargin) {
	int256 v = calculateV(perpetual);
        int256 m0 = v.wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE)).wmul(perpetual.settings.targetLeverage);
	int256 ma = account.cashBalance.add(v);
	deltaMargin = calculateLongDeltaMargin(m0, ma, account.positionAmount, account.positionAmount.sub(amount), perpetual.settings.beta1, perpetual);
    }

    function shortSideTrade(
	Perpetual storage perpetual,
	MarginAccount memory account,
	int256 amount
    ) internal view returns (int256 deltaMargin) {
	int256 v = calculateV(perpetual);
	int256 m0 = v.wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE)).wmul(perpetual.settings.targetLeverage);
	int256 ma = account.cashBalance.add(v);
	deltaMargin = calculateShortDeltaMargin(m0, account.positionAmount, account.positionAmount.sub(amount), perpetual.settings.beta1, perpetual);
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
            forceFunding(blockTime, newIndexPrice, newIndexTimestamp, perpetual, account);
        }
    }

    function forceFunding(
	uint256 blockTime,
	int256 newIndexPrice,
	uint256 newIndexTimestamp,
	Perpetual storage perpetual,
	MarginAccount memory account
    ) private {
        if (perpetual.state.lastFundingTime == 0) {
            // funding initialization required. but in this case, it's safe to just do nothing and return
            return;
        }
        if (newIndexTimestamp > perpetual.state.lastFundingTime) {
            // the 1st update
            nextStateWithTimespan(newIndexPrice, newIndexTimestamp, perpetual, account);
        }
        // the 2nd update;
        nextStateWithTimespan(newIndexPrice, blockTime, perpetual, account);
    }

    function nextStateWithTimespan(
        int256 newIndexPrice,
        uint256 endTimestamp,
	Perpetual storage perpetual,
	MarginAccount memory account
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
	perpetual.state.lastFundingRate = calculateFundingRate(perpetual, account);
    }

    function calculateFundingRate(
	Perpetual storage perpetual,
	MarginAccount memory account
    ) public returns (int256 fundingRate) {
	int256 v = calculateV(perpetual);
	int256 m0 = v.wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE)).wmul(perpetual.settings.targetLeverage);
	if (account.positionAmount == 0) {
	    fundingRate = 0;
	} else if (account.positionAmount > 0) {
	    int256 ma = account.cashBalance.add(v);
	    fundingRate = ma.wdiv(m0).sub(LibConstant.SIGNED_ONE).wmul(perpetual.settings.baseFundingRate);
	} else {
	    fundingRate = -perpetual.state.indexPrice.wmul(account.positionAmount).wdiv(m0).wmul(perpetual.settings.baseFundingRate);
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
        Context memory context,
        int256 amount
    ) public returns (int256 deltaMargin, int256 fee) {
	fee = 0;
	require(amount != 0, "no zero amount");
        MarginAccount memory ammAccount = context.makerAccount;
	funding(perpetual, ammAccount);
        if (amount > 0) {
	    // buy
	    if (ammAccount.positionAmount > 0) {
                if (amount > ammAccount.positionAmount) {
		    if (longSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			deltaMargin = longSideTrade(perpetual, ammAccount, ammAccount.positionAmount);
		    } else {
			deltaMargin = perpetual.state.indexPrice.wmul(ammAccount.positionAmount);
		    }
		    int256 v = calculateV(perpetual);
		    deltaMargin = shortSideTrade(perpetual, ammAccount, amount.sub(ammAccount.positionAmount));
		    int256 newV = calculateV(perpetual);
		    if (v != newV) {
		        revert("after buy unsafe(m0 change)");
		    }
		    if (!shortSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			revert("after buy unsafe");
		    }
		} else {
		    if (longSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			deltaMargin = longSideTrade(perpetual, ammAccount, amount);
		    } else {
			deltaMargin = perpetual.state.indexPrice.wmul(amount);
		    }
		}
	    } else {
		if (ammAccount.positionAmount == 0 || shortSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
		    int256 v = calculateV(perpetual);
		    deltaMargin = shortSideTrade(perpetual, ammAccount, amount);
		    int256 newV = calculateV(perpetual);
		    if (v != newV) {
			revert("after buy unsafe(m0 change)");
		    }
		    if (!shortSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			revert("after buy unsafe");
		    }
	        } else {
		    revert("before buy unsafe");
		}
	    }
	} else {
	    // sell
	    if (ammAccount.positionAmount < 0) {
		if (amount < ammAccount.positionAmount) {
		    if (shortSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			deltaMargin = shortSideTrade(perpetual, ammAccount, ammAccount.positionAmount);
		    } else {
			deltaMargin = -perpetual.state.indexPrice.wmul(ammAccount.positionAmount);
		    }
		    int256 v = calculateV(perpetual);
		    deltaMargin = longSideTrade(perpetual, ammAccount, amount.sub(ammAccount.positionAmount));
		    int256 newV = calculateV(perpetual);
		    if (v != newV) {
			revert("after sell unsafe(m0 change)");
		    }
		    if (!longSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			revert("after sell unsafe");
		    }
		} else {
		    if (shortSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			deltaMargin = shortSideTrade(perpetual, ammAccount, amount);
		    } else {
			deltaMargin = -perpetual.state.indexPrice.wmul(amount);
		    }
		}
	    } else {
		if (ammAccount.positionAmount == 0 || longSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
		    int256 v = calculateV(perpetual);
		    deltaMargin = longSideTrade(perpetual, ammAccount, amount);
		    int256 newV = calculateV(perpetual);
		    if (v != newV) {
			revert("after sell unsafe(m0 change)");
		    }
		    if (!longSafe(ammAccount.cashBalance, ammAccount.positionAmount, perpetual.settings.beta1, perpetual)) {
			revert("after sell unsafe");
		    }
		} else {
		    revert("before sell unsafe");
		}
	    }
	}
        /*
        - get open / close
        - do close xx
        - call updatePosition .. 
        - call updateCashBalance
        - do open
        -  margin marginAcount
        - call openPosition ..
        */
    }

    function calculateV(
        Perpetual storage perpetual
    ) public view returns (int256 virtualMargin) {
        MarginAccount memory account = perpetual.traderAccounts[address(this)];
        if (account.positionAmount == 0) {
            virtualMargin = perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(account.cashBalance);
        } else if (account.positionAmount > 0) {
            int256 b = perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(perpetual.state.indexPrice).wmul(account.positionAmount);
            b = b.add(perpetual.settings.targetLeverage.wmul(account.cashBalance));
            int256 beforeSqrt = perpetual.settings.beta1.wmul(perpetual.state.indexPrice).wmul(perpetual.settings.targetLeverage).wmul(account.cashBalance).mul(account.positionAmount).mul(4);
            beforeSqrt = beforeSqrt.add(b.mul(b));
            virtualMargin = perpetual.settings.beta1.sub(LibConstant.SIGNED_ONE).wmul(account.cashBalance).mul(2);
	    virtualMargin = virtualMargin.add(beforeSqrt.sqrt()).add(b);
	    virtualMargin = virtualMargin.wmul(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE));
	    virtualMargin = virtualMargin.wdiv(perpetual.settings.targetLeverage.add(perpetual.settings.beta1).sub(LibConstant.SIGNED_ONE)).div(2);
        } else {
	    int256 a = perpetual.state.indexPrice.wmul(account.positionAmount).mul(2);
	    int256 b = perpetual.settings.targetLeverage.add(LibConstant.SIGNED_ONE).wmul(perpetual.state.indexPrice).wmul(account.positionAmount);
	    b = b.add(perpetual.settings.targetLeverage.wmul(account.cashBalance));
	    int256 beforeSqrt = b.mul(b).sub(perpetual.settings.beta1.wmul(perpetual.settings.targetLeverage).wmul(a).mul(a));
	    virtualMargin = b.sub(a).add(beforeSqrt.sqrt());
	    virtualMargin = virtualMargin.wmul(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE));
	    virtualMargin = virtualMargin.wdiv(perpetual.settings.targetLeverage).div(2);
	}
    }

    function calculateLongDeltaMargin(
        int256 m0,
	int256 ma,
	int256 pos1,
	int256 pos2,
	int256 beta,
	Perpetual storage perpetual
    ) public view returns (int256 deltaMargin) {
	int256 a = LibConstant.SIGNED_ONE.sub(beta).wmul(ma).mul(2);
	int256 b = pos2.sub(pos1).wmul(perpetual.state.indexPrice);
	b = a.div(2).sub(b).wmul(ma);
	b = b.sub(beta.wmul(m0).wmul(m0));
	int256 beforeSqrt = beta.wmul(a).wmul(ma).wmul(m0).mul(m0).mul(2);
	beforeSqrt = beforeSqrt.add(b.mul(b));
	deltaMargin = beforeSqrt.sqrt().add(b).wdiv(a).sub(ma);
    }

    function calculateShortDeltaMargin(
	int256 m0,
	int256 pos1,
	int256 pos2,
	int256 beta,
	Perpetual storage perpetual
    ) public view returns (int256 deltaMargin) {
	deltaMargin = beta.wmul(m0).wmul(m0);
	deltaMargin = deltaMargin.wdiv(pos1.wmul(perpetual.state.indexPrice).add(m0));
	deltaMargin = deltaMargin.wdiv(pos2.wmul(perpetual.state.indexPrice).add(m0));
	deltaMargin = deltaMargin.add(LibConstant.SIGNED_ONE).sub(beta);
	deltaMargin = deltaMargin.wmul(perpetual.state.indexPrice).wmul(pos2.sub(pos1));
    }

    function longSafe(
	int256 cash,
	int256 pos,
	int256 beta,
	Perpetual storage perpetual
    ) public view returns (bool) {
	require(pos >= 0, "only for long");
	if (cash < 0) {
	    int256 minIndex = perpetual.settings.targetLeverage.add(beta).sub(LibConstant.SIGNED_ONE).mul(beta);
	    minIndex = minIndex.sqrt().mul(2).add(perpetual.settings.targetLeverage).sub(LibConstant.SIGNED_ONE);
	    minIndex = minIndex.add(beta.mul(2)).wmul(perpetual.settings.targetLeverage).wmul(-cash);
	    minIndex = minIndex.wdiv(pos).wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE)).wdiv(perpetual.settings.targetLeverage.sub(LibConstant.SIGNED_ONE));
	    return perpetual.state.indexPrice >= minIndex;
	} else {
	    return true;
	}
    }

    function shortSafe(
	int256 cash,
	int256 pos,
	int256 beta,
	Perpetual storage perpetual
    ) public view returns (bool) {
	require(pos <= 0, "only for short");
	int256 maxIndex = beta.mul(perpetual.settings.targetLeverage).sqrt().mul(2).add(perpetual.settings.targetLeverage).add(LibConstant.SIGNED_ONE);
	maxIndex = perpetual.settings.targetLeverage.wmul(cash).wdiv(-pos).wdiv(maxIndex);
	return perpetual.state.indexPrice <= maxIndex;
    }

    function addLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function removeLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function _buy() internal view {

    }

    function _sell() internal view {

    }
}
