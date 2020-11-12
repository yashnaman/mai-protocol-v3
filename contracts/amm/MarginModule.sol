// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../Type.sol";

library MarginModule {
    // using SafeMathExt for int256;
    // using SignedSafeMath for int256;

    // // Properties
    // function initialMargin(
    //     MarginAccount memory account,
    //     int256 markPrice,
    //     int256 initialMarginRate,
    //     int256 reservedMargin
    // ) public view returns (int256) {
    //     return account.positionAmount.wmul(markPrice).wmul(initialMarginRate).max(reservedMargin);
    // }

    // function maintenanceMargin(
    //     MarginAccount memory account,
    //     int256 markPrice,
    //     int256 maintenanceMarginRate,
    //     int256 reservedMargin
    // ) public view returns (int256) {
    //     return account.positionAmount.wmul(markPrice).wmul(maintenanceMarginRate).max(reservedMargin);
    // }

    // function availableCashBalance(
    //     MarginAccount memory account,
    //     int256 unitAccFundingLoss
    // ) public pure returns (int256) {
    //     int256 loss = unitAccFundingLoss.wmul(account.positionAmount).sub(account.entryFundingLoss);
	//     return account.cashBalance.sub(loss);
    // }

    // function margin(
    //     MarginAccount memory account,
    //     int256 markPrice,
    //     int256 unitAccFundingLoss
    // ) public pure returns (int256) {
    //     return availableCashBalance(account, unitAccFundingLoss).sub(account.positionAmount.wmul(markPrice));
    // }

    // function availableMargin(
    //     MarginAccount memory account,
    //     Settings storage settings,
    //     int256 markPrice
    // ) public view returns (int256) {
    //     return margin(account, markPrice).sub(initialMargin(account, settings, markPrice));
    // }

    // function withdrawableMargin(
    //     MarginAccount memory account,
    //     Settings storage settings,
    //     int256 markPrice
    // ) public view returns (int256) {
    //     int256 amount = margin(account, markPrice);
    //     if (account.positionAmount != 0) {
    //         amount = amount.sub(initialMargin(account, settings, markPrice));
    //     }
    //     return amount.max(0);
    // }

    // // Methods
    // function updatePosition(
    //     MarginAccount memory account,
    //     int256 positionAmount
    // ) internal pure {
    //     account.positionAmount = account.positionAmount.add(positionAmount);
    // }


    // function closePosition(
    //     MarginAccount memory account,
    //     int256 positionAmount
    // ) internal pure {
    //     int256 beforeClosingAmount = account.positionAmount;
    //     account.positionAmount = beforeClosingAmount.sub(positionAmount);
    //     if (positionAmount > 0) {
    //         account.entryFundingLoss = account.entryFundingLoss
    //             .wfrac(account.positionAmount.sub(positionAmount), account.positionAmount);
    //     }
    //     require(account.positionAmount.abs() <= beforeClosingAmount.abs(), "not closing");
    // }

    // function openPosition(
    //     MarginAccount memory account,
    //     int256 positionAmount,
    //     int256 unitAccumulatedFundingLoss
    // ) internal pure {
    //     int256 beforeOpeningAmount = account.positionAmount;
    //     account.positionAmount = beforeOpeningAmount.add(positionAmount);
    //     if (positionAmount > 0) {
    //         account.entryFundingLoss = account.entryFundingLoss
    //             .add(unitAccumulatedFundingLoss.wmul(positionAmount));
    //     }
    //     require(account.positionAmount.abs() >= beforeOpeningAmount.abs(), "not opening");
    // }

    // function increaseCashBalance(
    //     MarginAccount memory account,
    //     int256 amount
    // ) internal pure {
    //     account.cashBalance = account.cashBalance.add(amount);
    // }

    // function decreaseCashBalance(
    //     MarginAccount memory account,
    //     int256 amount
    // ) internal pure {
    //     account.cashBalance = account.cashBalance.sub(amount);
    // }
}