// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../lib/LibSafeMathExt.sol";
import "../lib/LibError.sol";
import "../Type.sol";

import "./MarginAccountImp.sol";
import "./AMMImp.sol";


library TradeImp {

    using SignedSafeMath for int256;
    using LibSafeMathExt for int256;
    using MarginAccountImp for Perpetual;
    using AMMImp for Perpetual;

    uint256 internal constant _MAX_PLAN_SIZE = 3;

    struct Recipe {
        int256[_MAX_PLAN_SIZE] plan;
        int256 takerOpeningAmount;
        int256 takerClosingAmount;
        int256 makerOpeningAmount;
        int256 makerClosingAmount;
    }

    function trade(
        Perpetual storage perpetual,
        Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public {
        Recipe memory recipe = tradePosition(perpetual, context, positionAmount, priceLimit);
        // safe check
        recipe.takerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.takerAccount) :
            perpetual.isMaintenanceMarginSafe(context.takerAccount);
        recipe.makerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.makerAccount) :
            perpetual.isMaintenanceMarginSafe(context.makerAccount);
    }

    function liquidate(
        Perpetual storage perpetual,
        Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public returns (int256) {
        // taker            = trader
        // maker            = amm
        // positionAmount   = amount from taker's side
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        Recipe memory recipe = tradePosition(perpetual, context, positionAmount, priceLimit);
        recipe.makerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.makerAccount) :
            perpetual.isMaintenanceMarginSafe(context.makerAccount);

        int256 liquidateValue = context.tradingPrice.wmul(positionAmount);
        int256 penaltyToLiquidator = perpetual.settings.liquidationGasReserve;
        int256 penaltyToLP = liquidateValue.wmul(perpetual.settings.liquidationPenaltyRate1);
        int256 penaltyToFund = liquidateValue.wmul(perpetual.settings.liquidationPenaltyRate2);
        int256 socialLoss = handleLiquidationLoss(perpetual, context, penaltyToLP, penaltyToFund);
        // TODO: socialLoss > 0
        return penaltyToLiquidator;
    }

    function liquidate2(
        Perpetual storage perpetual,
        Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public returns (int256) {
        // taker            = liquidator
        // maker            = amm
        // positionAmount   = liquidator from taker's side
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        takePosition(perpetual, context, positionAmount, priceLimit);

        int256 liquidateValue = context.tradingPrice.wmul(positionAmount);
        int256 penaltyToLiquidator = perpetual.settings.liquidationGasReserve;
        int256 penaltyToLiquidator2 = liquidateValue.wmul(perpetual.settings.liquidationPenaltyRate1);
        int256 penaltyToFund = liquidateValue.wmul(perpetual.settings.liquidationPenaltyRate2);
        int256 socialLoss = handleLiquidationLoss(perpetual, context, penaltyToLiquidator2, penaltyToFund);
        // TODO: socialLoss > 0
        return penaltyToLiquidator.add(penaltyToLiquidator2);
    }

    function takePosition(
        Perpetual storage perpetual,
        Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public {
        int256 takingPrice = perpetual.state.markPrice;
        require(_validatePrice(positionAmount, takingPrice, priceLimit), LibError.EXCEED_PRICE_LIMIT);
        context.tradingPrice = takingPrice;
        Recipe memory recipe;
        _splitAmount(context, recipe, positionAmount);
        int256 takenValue = takingPrice.wmul(positionAmount);
        context.takerAccount.cashBalance = context.takerAccount.cashBalance
            .sub(takenValue);
        context.makerAccount.cashBalance = context.makerAccount.cashBalance
            .add(takenValue);
        perpetual.updatePosition(context.takerAccount, recipe.takerClosingAmount, recipe.takerOpeningAmount);
        perpetual.updatePosition(context.makerAccount, recipe.makerClosingAmount, recipe.makerOpeningAmount);

        recipe.takerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.takerAccount) :
            perpetual.isMaintenanceMarginSafe(context.takerAccount);
        // recipe.makerOpeningAmount > 0 ?
        //     perpetual.isInitialMarginSafe(context.makerAccount) :
        //     perpetual.isMaintenanceMarginSafe(context.makerAccount);
    }

    function tradePosition(
        Perpetual storage perpetual,
        Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) internal returns (Recipe memory) {
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        // trade
        Recipe memory recipe;
        _splitAmount(context, recipe, positionAmount);
        _generateTradingPlan(context, recipe, positionAmount);
        ( int256 totalCashCost, int256 totalFeeCost ) = _executeTradingPlan(perpetual, context, recipe);
        // validation
        int256 tradingPrice = totalCashCost.wdiv(positionAmount);
        require(tradingPrice > 0, LibError.INVALID_TRADING_PRICE);
        require(_validatePrice(positionAmount, tradingPrice, priceLimit), LibError.EXCEED_PRICE_LIMIT);
        // fee
        int256 tradingValue = tradingPrice.wmul(positionAmount);
        context.vaultFee = tradingValue.wmul(perpetual.settings.vaultFeeRate);
        context.operatorFee = tradingValue.wmul(perpetual.settings.operatorFeeRate);
        context.lpFee = totalFeeCost;
        context.tradingPrice = tradingPrice;
        // update margin account
        int256 takerCost = totalCashCost.add(context.lpFee).add(context.vaultFee).add(context.operatorFee);
        context.takerAccount.cashBalance = context.takerAccount.cashBalance.sub(takerCost);
        context.makerAccount.cashBalance = context.makerAccount.cashBalance.add(totalCashCost);
        perpetual.updatePosition(context.takerAccount, recipe.takerClosingAmount, recipe.takerOpeningAmount);
        perpetual.updatePosition(context.makerAccount, recipe.makerClosingAmount, recipe.makerOpeningAmount);
        return recipe;
    }

    function handleLiquidationLoss(
        Perpetual storage perpetual,
        Context memory context,
        int256 penaltyToLiquidator,
        int256 penaltyToFund
    ) internal returns (int256) {
        int256 socialLoss = 0;
        int256 penalty = penaltyToLiquidator.add(penaltyToFund);
        if (context.takerAccount.cashBalance >= penalty) {
            context.takerAccount.cashBalance = context.takerAccount.cashBalance
                .sub(penalty);
            perpetual.state.insuranceFund = perpetual.state.insuranceFund.add(penaltyToFund);
        } else if (perpetual.margin(context.takerAccount).add(perpetual.state.insuranceFund) >= penaltyToLiquidator) {
            context.takerAccount.cashBalance = context.takerAccount.cashBalance
                .sub(perpetual.margin(context.takerAccount));
            perpetual.state.insuranceFund = perpetual.state.insuranceFund
                .sub(penaltyToLiquidator.sub(perpetual.margin(context.takerAccount)));
        } else {
            context.takerAccount.cashBalance = context.takerAccount.cashBalance
                .sub(perpetual.margin(context.takerAccount));
            socialLoss = penaltyToLiquidator
                .sub(perpetual.state.insuranceFund)
                .sub(perpetual.margin(context.takerAccount))
                .div(perpetual.state.totalPositionAmount);
            perpetual.state.insuranceFund = 0;
        }
        return socialLoss;
    }

    function _validatePrice(int256 positionAmount, int256 price, int256 priceLimit) internal pure returns (bool) {
        return positionAmount >= 0? price < priceLimit: price > priceLimit;
    }

    function _splitAmount(
        Context memory context,
        Recipe memory recipe,
        int256 positionAmount
    ) internal {
        (
            recipe.takerClosingAmount,
            recipe.takerOpeningAmount
        ) = Utils.splitAmount(context.takerAccount.positionAmount, positionAmount);
        (
            recipe.makerClosingAmount,
            recipe.makerOpeningAmount
        ) = Utils.splitAmount(context.makerAccount.positionAmount, positionAmount.neg());
    }

    function _generateTradingPlan(
        Context memory context,
        Recipe memory recipe,
        int256 positionAmount
    ) internal {
        int256 sign = Utils.extractSign(positionAmount);
        recipe.plan[0] = recipe.takerClosingAmount.abs()
            .min(recipe.makerClosingAmount.abs())
            .mul(sign);
        recipe.plan[1] = recipe.takerClosingAmount
            .add(recipe.makerClosingAmount).abs()
            .mul(sign);
        recipe.plan[2] = positionAmount
            .sub(recipe.plan[0])
            .sub(recipe.plan[1]);
    }

    function _executeTradingPlan(
        Perpetual storage perpetual,
        Context memory context,
        Recipe memory recipe
    ) internal returns (int256, int256) {
        int256 totalCashCost = 0;
        int256 totalFeeCost = 0;
        for (uint256 i = 0; i < _MAX_PLAN_SIZE; i++) {
            int256 tradingAmount = recipe.plan[i];
            if (tradingAmount == 0) {
                continue;
            }
            int256 cashCost = perpetual.determineDeltaCashBalance(context.makerAccount, tradingAmount);
            totalCashCost = totalCashCost.add(cashCost);
        }
        return (totalCashCost, totalFeeCost);
    }

}
