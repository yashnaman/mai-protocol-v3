// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/Constant.sol";
import "../libraries/SafeMathExt.sol";
import "./MarginModule.sol";
import "./CollateralModule.sol";

library SettlementModule {
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using EnumerableSet for EnumerableSet.AddressSet;

    using MarginModule for Core;
    using CollateralModule for Core;

    function registerTrader(Core storage core, address trader) internal {
        core.registeredTraders.add(trader);
    }

    function deregisterTrader(Core storage core, address trader) internal {
        core.registeredTraders.remove(trader);
    }

    function clearMarginAccount(Core storage core, address trader) public {
        require(core.registeredTraders.contains(trader), "trader is not registered");
        require(!core.clearedTraders.contains(trader), "trader is already cleared");
        int256 margin = core.margin(trader);
        // into 3 types:
        // 1. margin < 0
        // 2. margin > 0 && position amount > 0
        // 3. margin > 0 && position amount == 0
        if (margin > 0) {
            if (core.marginAccounts[trader].positionAmount != 0) {
                core.totalMarginWithPosition = core.totalMarginWithPosition.add(margin);
            } else {
                core.totalMarginWithoutPosition = core.totalMarginWithoutPosition.add(margin);
            }
        }
        core.clearingPayout.add(core.keeperGasReward);
        core.registeredTraders.remove(trader);
        core.clearedTraders.add(trader);
    }

    function settledMarginAccount(Core storage core, address trader)
        public
        returns (int256 amount)
    {
        int256 margin = core.margin(trader);
        int256 positionAmount = core.positionAmount(trader);
        // nothing to withdraw
        if (margin < 0) {
            return 0;
        }
        int256 rate = positionAmount == 0
            ? core.redemptionRateWithoutPosition
            : core.redemptionRateWithPosition;
        int256 withdrawable = margin.wmul(rate);
        core.updateCashBalance(trader, margin.neg());
        return withdrawable;
    }

    function updateWithdrawableMargin(Core storage core) public {
        int256 totalBalance = core.collateralBalance(address(this));
        // 1. exclude fees
        totalBalance = totalBalance.sub(core.totalClaimableFee);
        // 2. cover margin without position
        if (totalBalance < core.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            core.redemptionRateWithoutPosition = totalBalance.wdiv(core.totalMarginWithoutPosition);
            // margin with positions will get nothing
            core.redemptionRateWithPosition = 0;
            return;
        } else {
            // 3. covere margin with position
            core.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            core.redemptionRateWithPosition = totalBalance
                .sub(core.totalMarginWithoutPosition)
                .wdiv(core.totalMarginWithPosition);
        }
    }
}
