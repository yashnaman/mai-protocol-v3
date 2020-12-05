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

    using MarginModule for Market;
    using CollateralModule for Market;

    function registerTrader(Market storage market, address trader) internal {
        market.registeredTraders.add(trader);
    }

    function deregisterTrader(Market storage market, address trader) internal {
        market.registeredTraders.remove(trader);
    }

    function clearMarginAccount(Market storage market, address trader) public {
        require(market.registeredTraders.contains(trader), "trader is not registered");
        require(!market.clearedTraders.contains(trader), "trader is already cleared");
        int256 margin = market.margin(trader);
        // into 3 types:
        // 1. margin < 0
        // 2. margin > 0 && position amount > 0
        // 3. margin > 0 && position amount == 0
        if (margin > 0) {
            if (market.marginAccounts[trader].positionAmount != 0) {
                market.totalMarginWithPosition = market.totalMarginWithPosition.add(margin);
            } else {
                market.totalMarginWithoutPosition = market.totalMarginWithoutPosition.add(margin);
            }
        }
        market.registeredTraders.remove(trader);
        market.clearedTraders.add(trader);
    }

    function settledMarginAccount(Market storage market, address trader)
        public
        returns (int256 amount)
    {
        int256 margin = market.margin(trader);
        int256 positionAmount = market.positionAmount(trader);
        // nothing to withdraw
        if (margin < 0) {
            return 0;
        }
        int256 rate = positionAmount == 0
            ? market.redemptionRateWithoutPosition
            : market.redemptionRateWithPosition;
        int256 withdrawable = margin.wmul(rate);
        market.updateCashBalance(trader, margin.neg());
        return withdrawable;
    }

    function updateWithdrawableMargin(Market storage market, int256 totalBalance) public {
        // 2. cover margin without position
        if (totalBalance < market.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            market.redemptionRateWithoutPosition = totalBalance.wdiv(
                market.totalMarginWithoutPosition
            );
            // margin with positions will get nothing
            market.redemptionRateWithPosition = 0;
            return;
        } else {
            // 3. covere margin with position
            market.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            market.redemptionRateWithPosition = totalBalance
                .sub(market.totalMarginWithoutPosition)
                .wdiv(market.totalMarginWithPosition);
        }
    }
}
