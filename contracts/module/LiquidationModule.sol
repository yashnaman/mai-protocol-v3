// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./OracleModule.sol";
import "./TradeModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

library LiquidationModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;

    address internal constant INVALID_ADDRESS = address(0);

    event Liquidate(
        uint256 perpetualIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );

    function liquidateByAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        address liquidator = msg.sender;
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(trader), "trader is safe");
        int256 maxAmount = perpetual.marginAccounts[trader].position;
        require(maxAmount != 0, "amount is invalid");
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) = liquidityPool.tradeWithAMM(
            perpetualIndex,
            maxAmount,
            false
        );
        int256 liquidatePrice = deltaCash.wdiv(deltaPosition).abs();
        // 1. execute
        perpetual.updateMarginAccount(address(this), deltaPosition, deltaCash);
        perpetual.updateMarginAccount(trader, deltaPosition.neg(), deltaCash.neg());
        // 3. penalty
        {
            int256 liquidatePenalty = perpetual
                .getMarkPrice()
                .wmul(deltaPosition)
                .wmul(perpetual.liquidationPenaltyRate)
                .abs();
            (int256 penaltyToTaker, int256 penaltyToFund) = getLiquidationPenalty(
                perpetual,
                trader,
                liquidatePenalty,
                perpetual.keeperGasReward
            );
            require(penaltyToTaker >= 0, "penalty to taker should be greater than 0");
            perpetual.updateCash(address(this), penaltyToTaker);
            perpetual.updateInsuranceFund(penaltyToFund);
            liquidityPool.transferToUser(payable(liquidator), perpetual.keeperGasReward);
        }
        // 4. events
        emit Liquidate(perpetualIndex, address(this), trader, deltaPosition, liquidatePrice);
        // 5. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            perpetual.enterEmergencyState();
        }
    }

    function liquidateByTrader(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(trader), "trader is safe");
        // 0. price / amountyo
        int256 liquidatePrice = perpetual.getMarkPrice();
        TradeModule.validatePrice(amount > 0, liquidatePrice, limitPrice);
        (int256 deltaCash, int256 deltaPosition) = (liquidatePrice.wmul(amount), amount.neg());
        // 1. execute
        bool isOpen = Utils.isOpen(perpetual.getPosition(liquidator), amount);
        perpetual.updateMarginAccount(trader, deltaPosition, deltaCash);
        perpetual.updateMarginAccount(liquidator, deltaPosition.neg(), deltaCash.neg());
        // 2. penalty
        {
            int256 liquidatePenalty = deltaCash.wmul(perpetual.liquidationPenaltyRate).abs();
            (int256 penaltyToTaker, int256 penaltyToFund) = getLiquidationPenalty(
                perpetual,
                trader,
                liquidatePenalty,
                0
            );
            require(penaltyToTaker >= 0, "penalty to taker should be greater than 0");
            perpetual.updateCash(liquidator, penaltyToTaker);
            perpetual.updateInsuranceFund(penaltyToFund);
        }
        // 3. safe
        if (isOpen) {
            require(perpetual.isInitialMarginSafe(liquidator), "trader initial margin unsafe");
        } else {
            require(
                perpetual.isMaintenanceMarginSafe(liquidator),
                "trader maintenance margin unsafe"
            );
        }
        // 4. events
        emit Liquidate(perpetualIndex, liquidator, trader, deltaPosition, liquidatePrice);
        // 5. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            perpetual.enterEmergencyState();
        }
    }

    function getLiquidationPenalty(
        PerpetualStorage storage perpetual,
        address trader,
        int256 softPenalty,
        int256 hardPenalty
    ) internal returns (int256 penaltyToTaker, int256 penaltyToFund) {
        require(softPenalty >= 0, "soft penalty is negative");
        require(hardPenalty >= 0, "hard penalty is negative");
        int256 fullPenalty = hardPenalty.add(softPenalty);
        int256 traderMargin = perpetual.getMargin(trader, perpetual.getMarkPrice());
        int256 traderMarginLeft = fullPenalty.min(traderMargin).sub(hardPenalty);
        if (traderMarginLeft > 0) {
            penaltyToFund = traderMarginLeft.wmul(perpetual.insuranceFundRate); // + insuranceFund
            penaltyToTaker = traderMarginLeft.sub(penaltyToFund); // + taker
        } else {
            penaltyToFund = traderMarginLeft; // - insuranceFund
            penaltyToTaker = 0; // no
        }
    }

    // function handleInsuranceFund(
    //     LiquidityPoolStorage storage liquidityPool,
    //     PerpetualStorage storage perpetual,
    //     int256 penalty
    // ) internal returns (bool isInsuranceFundDrained) {
    //     int256 penaltyToFund;
    //     int256 penaltyToLP;
    //     if (
    //         penalty < 0 ||
    //         liquidityPool.insuranceFund.add(penalty) <= liquidityPool.insuranceFundCap
    //     ) {
    //         penaltyToFund = penalty;
    //         penaltyToLP = 0;
    //     } else if (liquidityPool.insuranceFund > liquidityPool.insuranceFundCap) {
    //         penaltyToFund = 0;
    //         penaltyToLP = penalty;
    //     } else {
    //         int256 fundToFill = liquidityPool.insuranceFundCap.sub(liquidityPool.insuranceFund);
    //         penaltyToFund = fundToFill;
    //         penaltyToLP = penalty.sub(fundToFill);
    //     }
    //     return liquidityPool.updateInsuranceFund(perpetual, penaltyToFund, penaltyToLP);
    // }
}
