// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../Type.sol";
import "./OracleModule.sol";
import "./StateModule.sol";

library MarginModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using OracleModule for Core;

    // atribute
    function initialMargin(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.initialMarginRate)
                .max(core.keeperGasReward);
    }

    function maintenanceMargin(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .wmul(core.maintenanceMarginRate)
                .max(core.keeperGasReward);
    }

    function cashBalance(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        int256 fundingLoss = core.marginAccounts[trader].entryFundingLoss.sub(
            core.marginAccounts[trader].positionAmount.wmul(
                core.unitAccumulatedFundingLoss
            )
        );
        return core.marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function margin(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        return
            core.marginAccounts[trader]
                .positionAmount
                .wmul(core.markPrice())
                .add(cashBalance(core, trader));
    }

    function availableMargin(Core storage core, address trader)
        internal
        view
        returns (int256)
    {
        return margin(core, trader).sub(initialMargin(core, trader));
    }

    function isInitialMarginSafe(Core storage core, address trader)
        internal
        view
        returns (bool)
    {
        return margin(core, trader) >= initialMargin(core, trader);
    }

    function isMaintenanceMarginSafe(Core storage core, address trader)
        internal
        view
        returns (bool)
    {
        return margin(core, trader) >= maintenanceMargin(core, trader);
    }

    function closePosition(MarginAccount memory account, int256 amount)
        internal
        view
    {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.sub(amount);
        require(
            account.positionAmount.abs() <= previousAmount.abs(),
            "not closing"
        );
    }

    function openPosition(MarginAccount memory account, int256 amount)
        internal
        view
    {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(
            account.positionAmount.abs() >= previousAmount.abs(),
            "not opening"
        );
    }
}
