// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeMathExt.sol";
import "./MarginModule.sol";
import "./StateModule.sol";

library SettleModule {
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using EnumerableSet for EnumerableSet.AddressSet;

    using MarginModule for Core;
    using StateModule for Core;

    function registerTrader(Core storage core, address trader) internal {
        core.registeredTraders.add(trader);
    }

    function deregisterTrader(Core storage core, address trader) internal {
        core.registeredTraders.remove(trader);
    }

    function listTraderToClear(
        Core storage core,
        uint256 begin,
        uint256 end
    ) internal view returns (address[] memory) {
        require(end <= core.registeredTraders.length(), "exceeded");
        address[] memory result = new address[](end.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = core.registeredTraders.at(i);
        }
        return result;
    }

    function isCleared(Core storage core) internal view returns (bool) {
        return core.registeredTraders.length() == 0;
    }

    function clear(Core storage core, address trader) internal {
        int256 margin = core.margin(trader);
        if (core.marginAccounts[trader].positionAmount != 0) {
            core.marginWithPosition = core.marginWithPosition.add(margin);
        } else {
            core.marginWithoutPosition = core.marginWithoutPosition.add(margin);
        }
        bool removed = core.registeredTraders.remove(trader);
        require(removed, "already cleared");
        core.clearedTraders.add(trader);

        if (isCleared(core)) {
            setWithdrawableMargin(core);
        }
    }

    function setWithdrawableMargin(Core storage core) internal {
        int256 totalBalance;
        if (totalBalance < core.marginWithoutPosition) {
            core.withdrawableMarginWithoutPosition = totalBalance;
            totalBalance = 0;
        } else {
            core.withdrawableMarginWithoutPosition = core.marginWithoutPosition;
            totalBalance = totalBalance.sub(core.marginWithoutPosition);
        }
        if (totalBalance > 0) {
            core.withdrawableMarginWithPosition = totalBalance;
        } else {
            core.withdrawableMarginWithPosition = 0;
        }
        core.enterShuttingDownState();
    }

    function settle(Core storage core, address trader)
        internal
        returns (int256 amount)
    {
        int256 margin = core.margin(trader);
        if (core.marginAccounts[trader].positionAmount != 0) {
            amount = core.withdrawableMarginWithPosition.wfrac(
                margin,
                core.marginWithPosition
            );
            core.marginWithPosition = core.marginWithPosition.sub(margin);
            core.withdrawableMarginWithPosition = core
                .withdrawableMarginWithPosition
                .sub(amount);
        } else {
            amount = core.withdrawableMarginWithoutPosition.wfrac(
                margin,
                core.marginWithoutPosition
            );
            core.marginWithoutPosition = core.marginWithoutPosition.sub(margin);
            core.withdrawableMarginWithoutPosition = core
                .withdrawableMarginWithoutPosition
                .sub(amount);
        }
    }
}
