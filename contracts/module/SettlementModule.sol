// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../libraries/Constant.sol";
import "../libraries/SafeMathExt.sol";

import "./CollateralModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./OracleModule.sol";

library SettlementModule {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    using MarginModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    event Clear(uint256 perpetualIndex, address trader);
    event Settle(uint256 perpetualIndex, address trader, int256 amount);

    function clear(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(perpetual.activeAccounts.contains(trader), "trader is not registered");
        require(!perpetual.clearedTraders.contains(trader), "trader is already cleared");
        int256 margin = perpetual.margin(trader, perpetual.markPrice());
        if (margin > 0) {
            if (perpetual.marginAccounts[trader].positionAmount != 0) {
                perpetual.totalMarginWithPosition = perpetual.totalMarginWithPosition.add(margin);
            } else {
                perpetual.totalMarginWithoutPosition = perpetual.totalMarginWithoutPosition.add(
                    margin
                );
            }
        }
        perpetual.activeAccounts.remove(trader);
        perpetual.clearedTraders.add(trader);
        emit Clear(perpetualIndex, trader);

        if (perpetual.activeAccounts.length() == 0) {
            settleWithdrawableMargin(perpetual, 0);
            perpetual.enterClearedState();
        }
    }

    function settle(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        require(trader != address(0), "trader is invalid");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 withdrawable = settledMarginAccount(perpetual, trader);
        perpetual.updateCashBalance(trader, withdrawable.neg());
        liquidityPool.transferToUser(payable(trader), withdrawable);
        emit Settle(perpetualIndex, trader, withdrawable);
    }

    function registerActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.add(trader);
    }

    function deregisterActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.remove(trader);
    }

    function settledMarginAccount(PerpetualStorage storage perpetual, address trader)
        public
        returns (int256 amount)
    {
        int256 margin = perpetual.margin(trader, perpetual.markPrice());
        int256 positionAmount = perpetual.positionAmount(trader);
        // nothing to withdraw
        if (margin < 0) {
            return 0;
        }
        int256 rate = positionAmount == 0
            ? perpetual.redemptionRateWithoutPosition
            : perpetual.redemptionRateWithPosition;
        int256 withdrawable = margin.wmul(rate);
        perpetual.updateCashBalance(trader, margin.neg());
        return withdrawable;
    }

    function settleWithdrawableMargin(PerpetualStorage storage perpetual, int256 totalBalance)
        public
    {
        // 2. cover margin without position
        if (totalBalance < perpetual.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            perpetual.redemptionRateWithoutPosition = totalBalance.wdiv(
                perpetual.totalMarginWithoutPosition
            );
            // margin with positions will get nothing
            perpetual.redemptionRateWithPosition = 0;
            return;
        } else {
            // 3. covere margin with position
            perpetual.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            perpetual.redemptionRateWithPosition = totalBalance
                .sub(perpetual.totalMarginWithoutPosition)
                .wdiv(perpetual.totalMarginWithPosition);
        }
    }
}
