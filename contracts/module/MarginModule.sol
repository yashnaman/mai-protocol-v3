// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../Type.sol";

library MarginModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    // Properties

    function initialMargin(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice
    ) public view returns (int256) {
        return account.positionAmount
            .wmul(markPrice)
            .wmul(settings.initialMarginRate)
            .max(settings.reservedMargin);
    }

    function maintenanceMargin(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice
    ) public view returns (int256) {
        return account.positionAmount
            .wmul(markPrice)
            .wmul(settings.maintenanceMarginRate)
            .max(settings.reservedMargin);
    }

    // function availableCashBalance(
    //     MarginAccount memory account
    // ) public view returns (int256) {
	//     return account.cashBalance.sub(fundingLoss(account)).sub(socialLoss(account));
    // }

    function margin(
        MarginAccount memory account,
        int256 markPrice,
        int256 unitAccumulatedFundingLoss
    ) public pure returns (int256) {
        return account.cashBalance
            .sub(account.positionAmount.wmul(markPrice))
            .sub(fundingLoss(account, unitAccumulatedFundingLoss));
    }

    function availableMargin(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice,
        int256 unitAccumulatedFundingLoss
    ) public view returns (int256) {
        return margin(account, markPrice, unitAccumulatedFundingLoss)
            .sub(initialMargin(account, settings, markPrice));
    }

    function withdrawableMargin(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice,
        int256 unitAccumulatedFundingLoss
    ) public view returns (int256) {
        int256 amount = margin(account, markPrice, unitAccumulatedFundingLoss);
        if (account.positionAmount != 0) {
            amount = amount.sub(initialMargin(account, settings, markPrice));
        }
        return amount.max(0);
    }

    function fundingLoss(
        MarginAccount memory account,
        int256 unitAccumulatedFundingLoss
    ) public pure returns (int256) {
        return unitAccumulatedFundingLoss.wmul(account.positionAmount)
            .sub(account.entryFundingLoss);
    }

    function isInitialMarginSafe(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice,
        int256 unitAccumulatedFundingLoss
    ) public view returns (bool) {
        return margin(account, markPrice, unitAccumulatedFundingLoss)
            >= initialMargin(account, settings, markPrice);
    }

    function isMaintenanceMarginSafe(
        MarginAccount memory account,
        Settings storage settings,
        int256 markPrice,
        int256 unitAccumulatedFundingLoss
    ) public view returns (bool) {
        return margin(account, markPrice, unitAccumulatedFundingLoss)
            >= maintenanceMargin(account, settings, markPrice);
    }

    // Methods

    function updatePosition(
        MarginAccount memory account,
        int256 closingPositionAmount,
        int256 openingPositionAmount,
        int256 unitAccumulatedFundingLoss
    ) internal pure {
        account.positionAmount = account.positionAmount
            .add(closingPositionAmount)
            .add(openingPositionAmount);
        if (closingPositionAmount > 0) {
            account.entryFundingLoss = account.entryFundingLoss
                .wfrac(account.positionAmount.sub(closingPositionAmount), account.positionAmount);
        }
        if (openingPositionAmount > 0) {
            account.entryFundingLoss = account.entryFundingLoss
                .add(unitAccumulatedFundingLoss.wmul(openingPositionAmount));
        }
    }


    function closePosition(
        MarginAccount memory account,
        int256 positionAmount
    ) internal pure {
        int256 beforeClosingAmount = account.positionAmount;
        account.positionAmount = beforeClosingAmount.sub(positionAmount);
        if (positionAmount > 0) {
            account.entryFundingLoss = account.entryFundingLoss
                .wfrac(account.positionAmount.sub(positionAmount), account.positionAmount);
        }
        require(account.positionAmount.abs() <= beforeClosingAmount.abs(), "not closing");
    }

    function openPosition(
        MarginAccount memory account,
        int256 positionAmount,
        int256 unitAccumulatedFundingLoss
    ) internal pure {
        int256 beforeOpeningAmount = account.positionAmount;
        account.positionAmount = beforeOpeningAmount.add(positionAmount);
        if (positionAmount > 0) {
            account.entryFundingLoss = account.entryFundingLoss
                .add(unitAccumulatedFundingLoss.wmul(positionAmount));
        }
        require(account.positionAmount.abs() >= beforeOpeningAmount.abs(), "not opening");
    }

    function increaseCashBalance(
        MarginAccount memory account,
        int256 amount
    ) internal pure {
        account.cashBalance = account.cashBalance.add(amount);
    }

    function decreaseCashBalance(
        MarginAccount memory account,
        int256 amount
    ) internal pure {
        account.cashBalance = account.cashBalance.sub(amount);
    }
}