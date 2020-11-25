// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../Type.sol";
import "./OracleModule.sol";
import "./StateModule.sol";

library MarginModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using OracleModule for Core;

    // atribute
    function initialMargin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.initialMarginRate)
                .max(core.keeperGasReward);
    }

    function maintenanceMargin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.maintenanceMarginRate)
                .max(core.keeperGasReward);
    }

    function cashBalance(Core storage core, address trader) internal view returns (int256) {
        int256 fundingLoss = core.marginAccounts[trader].positionAmount.wmul(
            core.unitAccumulativeFunding).sub(core.marginAccounts[trader].entryFundingLoss);
        return core.marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function positionAmount(Core storage core, address trader) internal view returns (int256) {
        return core.marginAccounts[trader].positionAmount;
    }

    function margin(Core storage core, address trader) internal view returns (int256) {
        return
            core.marginAccounts[trader].positionAmount.wmul(core.markPrice()).add(
                cashBalance(core, trader)
            );
    }

    function availableMargin(Core storage core, address trader) internal view returns (int256) {
        return margin(core, trader).sub(initialMargin(core, trader));
    }

    function isInitialMarginSafe(Core storage core, address trader) internal view returns (bool) {
        return margin(core, trader) >= initialMargin(core, trader);
    }

    function isMaintenanceMarginSafe(Core storage core, address trader)
        internal
        view
        returns (bool)
    {
        return margin(core, trader) >= maintenanceMargin(core, trader);
    }

    function updateCashBalance(
        Core storage core,
        address trader,
        int256 amount
    ) internal {
        core.marginAccounts[trader].cashBalance = core.marginAccounts[trader].cashBalance.add(
            amount
        );
    }

    function updateMarginAccount(
        Core storage core,
        address trader,
        int256 deltaPositionAmount,
        int256 deltaMargin
    )
        internal
        returns (
            int256 fundingLoss,
            int256 closingAmount,
            int256 openingAmount
        )
    {
        MarginAccount memory account = core.marginAccounts[trader];
        (closingAmount, openingAmount) = Utils.splitAmount(
            account.positionAmount,
            deltaPositionAmount
        );
        if (closingAmount != 0) {
            closePosition(core, account, closingAmount);
            fundingLoss = core.marginAccounts[trader].cashBalance.sub(account.cashBalance);
        }
        if (openingAmount != 0) {
            openPosition(core, account, openingAmount);
        }
        account.cashBalance = account.cashBalance.add(deltaMargin);
        core.marginAccounts[trader] = account;
    }

    function closePosition(
        Core storage core,
        MarginAccount memory account,
        int256 amount
    ) internal view {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.sub(amount);
        require(account.positionAmount.abs() <= previousAmount.abs(), "not closing");
        int256 partialLoss = account.entryFundingLoss.wfrac(amount, account.positionAmount);
        int256 actualLoss = core.unitAccumulativeFunding.wmul(amount).sub(partialLoss);
        account.cashBalance = account.cashBalance.sub(actualLoss);
        account.entryFundingLoss = account.entryFundingLoss.sub(partialLoss);
    }

    function openPosition(
        Core storage core,
        MarginAccount memory account,
        int256 amount
    ) internal view {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(account.positionAmount.abs() >= previousAmount.abs(), "not opening");
        account.entryFundingLoss = account.entryFundingLoss.add(
            core.unitAccumulativeFunding.wmul(amount)
        );
    }
}
