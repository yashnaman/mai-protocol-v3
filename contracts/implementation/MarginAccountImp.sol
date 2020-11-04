// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../lib/LibSafeMathExt.sol";
import "../lib/LibUtils.sol";
import "../Type.sol";

library MarginAccountImp {

    using SignedSafeMath for int256;
    using LibSafeMathExt for int256;

    function initialMargin(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        return account.positionAmount
            .wmul(perpetual.state.markPrice)
            .wmul(perpetual.settings.initialMarginRate)
            .max(perpetual.settings.reservedMargin);
    }

    function maintenanceMargin(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        return account.positionAmount
            .wmul(perpetual.state.markPrice)
            .wmul(perpetual.settings.maintenanceMarginRate)
            .max(perpetual.settings.reservedMargin);
    }

    function margin(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        return account.cashBalance
            .sub(account.positionAmount.wmul(perpetual.state.markPrice))
            .sub(fundingLoss(perpetual, account))
            .sub(socialLoss(perpetual, account));
    }

    function availableMargin(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        return margin(perpetual, account).sub(initialMargin(perpetual, account));
    }

    function withdrawableMargin(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        return availableMargin(perpetual, account).max(0);
    }

    function isInitialMarginSafe(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (bool) {
        return margin(perpetual, account) >= initialMargin(perpetual, account);
    }

    function isMaintenanceMarginSafe(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (bool) {
        return margin(perpetual, account) >= maintenanceMargin(perpetual, account);
    }

    function availableCashBalance(
	Perpetual storage perpetual,
	MarginAccount memory account
    ) public view returns (int256) {
	return account.cashBalance.sub(fundingLoss(perpetual, account)).sub(socialLoss(perpetual, account));
    }

    function socialLoss(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        int256 loss = account.positionAmount.wmul(perpetual.state.unitSocialLoss);
        return loss.sub(account.entrySocialLoss);
    }

    function fundingLoss(
        Perpetual storage perpetual,
        MarginAccount memory account
    ) public view returns (int256) {
        int256 loss = perpetual.state.unitAccumulatedFundingLoss.wmul(account.positionAmount);
        return loss.sub(account.entryFundingLoss);
    }

    function updatePosition(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 closingPositionAmount,
        int256 openingPositionAmount
    ) public view {
        account.positionAmount = account.positionAmount
            .add(closingPositionAmount)
            .add(openingPositionAmount);
        if (closingPositionAmount > 0) {
            updateClosingLoss(perpetual, account, closingPositionAmount);
        }
        if (openingPositionAmount > 0) {
            updateOpeningLoss(perpetual, account, openingPositionAmount);
        }
    }

    function updateOpeningLoss(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 positionAmount
    ) internal view {
        account.entrySocialLoss = account.entrySocialLoss
                .add(perpetual.state.unitSocialLoss.wmul(positionAmount));
        account.entryFundingLoss = account.entryFundingLoss
                .add(perpetual.state.unitAccumulatedFundingLoss.wmul(positionAmount));
    }

    function updateClosingLoss(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 positionAmount
    ) internal view {
        account.entrySocialLoss = account.entrySocialLoss
                .wfrac(account.positionAmount.sub(positionAmount), account.positionAmount);
        account.entryFundingLoss = account.entryFundingLoss
                .wfrac(account.positionAmount.sub(positionAmount), account.positionAmount);
    }

    function deposit(
        Perpetual storage,
        MarginAccount memory account,
        int256 amount
    ) public pure returns (int256) {
        account.cashBalance = account.cashBalance.add(amount);
    }

    function withdraw(
        Perpetual storage perpetual,
        MarginAccount memory account,
        int256 amount
    ) public view returns (int256) {
        account.cashBalance = account.cashBalance.sub(amount);
        isInitialMarginSafe(perpetual, account);
    }
}
