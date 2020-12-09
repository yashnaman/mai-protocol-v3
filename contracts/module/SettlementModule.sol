// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../libraries/Constant.sol";
import "../libraries/SafeMathExt.sol";

import "./MarginModule.sol";
import "./MarketModule.sol";
import "./CollateralModule.sol";
import "./CoreModule.sol";

library SettlementModule {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    using MarginModule for Market;
    using MarketModule for Market;
    using CollateralModule for Core;
    using CoreModule for Core;

    event Clear(address trader);
    event Settle(address trader, int256 amount);

    function clear(
        Core storage core,
        bytes32 marketID,
        address trader
    ) public {
        Market storage market = core.markets[marketID];
        require(market.registeredTraders.contains(trader), "trader is not registered");
        require(!market.clearedTraders.contains(trader), "trader is already cleared");
        int256 margin = market.margin(trader);
        if (margin > 0) {
            if (market.marginAccounts[trader].positionAmount != 0) {
                market.totalMarginWithPosition = market.totalMarginWithPosition.add(margin);
            } else {
                market.totalMarginWithoutPosition = market.totalMarginWithoutPosition.add(margin);
            }
        }
        market.registeredTraders.remove(trader);
        market.clearedTraders.add(trader);

        if (market.registeredTraders.length() == 0) {
            settleWithdrawableMargin(market, 0);
            market.enterClearedState();
        }
    }

    function settle(
        Core storage core,
        bytes32 marketID,
        address trader
    ) public {
        require(trader != address(0), "trader is invalid");
        Market storage market = core.markets[marketID];
        int256 withdrawable = settledMarginAccount(market, trader);
        market.updateCashBalance(trader, withdrawable.neg());
        core.transferToUser(payable(trader), withdrawable);
        emit Settle(trader, withdrawable);
    }

    function registerTrader(Market storage market, address trader) internal {
        market.registeredTraders.add(trader);
    }

    function deregisterTrader(Market storage market, address trader) internal {
        market.registeredTraders.remove(trader);
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

    function settleWithdrawableMargin(Market storage market, int256 totalBalance) public {
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
