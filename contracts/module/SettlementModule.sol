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

import "hardhat/console.sol";

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

    event ClearAccount(uint256 perpetualIndex, address trader);
    event SettleAccount(uint256 perpetualIndex, address trader, int256 amount);

    function nextAccountToclear(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        public
        view
        returns (address account)
    {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(perpetual.activeAccounts.length() > 0, "no account to clear");
        account = perpetual.activeAccounts.at(0);
    }

    function clearAccount(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(perpetual.activeAccounts.contains(trader), "trader is not registered");
        require(!perpetual.clearedTraders.contains(trader), "trader is already cleared");
        int256 margin = perpetual.margin(trader, perpetual.markPrice());
        if (margin > 0) {
            if (perpetual.positionAmount(trader) != 0) {
                perpetual.totalMarginWithPosition = perpetual.totalMarginWithPosition.add(margin);
            } else {
                perpetual.totalMarginWithoutPosition = perpetual.totalMarginWithoutPosition.add(
                    margin
                );
            }
        }
        perpetual.activeAccounts.remove(trader);
        perpetual.clearedTraders.add(trader);
        emit ClearAccount(perpetualIndex, trader);

        if (perpetual.activeAccounts.length() == 0) {
            liquidityPool.rebalance(perpetual);
            settleCollateral(perpetual);
            perpetual.enterClearedState();
        }
    }

    function settleableMargin(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public view returns (int256 margin) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        margin = perpetual.margin(trader, perpetual.markPrice());
        if (margin > 0) {
            int256 rate = (perpetual.positionAmount(trader) == 0)
                ? perpetual.redemptionRateWithoutPosition
                : perpetual.redemptionRateWithPosition;
            margin = margin.wmul(rate);
        } else {
            margin = 0;
        }
    }

    function settleAccount(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        int256 withdrawable = settleableMargin(liquidityPool, perpetualIndex, trader);
        require(withdrawable > 0, "no margin to settle");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        liquidityPool.transferToUser(payable(trader), withdrawable);
        perpetual.reset(trader);
        emit SettleAccount(perpetualIndex, trader, withdrawable);
    }

    function registerActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.add(trader);
    }

    function deregisterActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.remove(trader);
    }

    function settleCollateral(PerpetualStorage storage perpetual) public {
        int256 totalCollateral = perpetual.collateralAmount;
        // 2. cover margin without position
        if (totalCollateral < perpetual.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            perpetual.redemptionRateWithoutPosition = totalCollateral.wdiv(
                perpetual.totalMarginWithoutPosition
            );
            // margin with positions will get nothing
            perpetual.redemptionRateWithPosition = 0;
        } else {
            // 3. covere margin with position
            perpetual.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            perpetual.redemptionRateWithPosition = totalCollateral
                .sub(perpetual.totalMarginWithoutPosition)
                .wdiv(perpetual.totalMarginWithPosition);
        }
    }
}
