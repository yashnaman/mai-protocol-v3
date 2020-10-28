// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./Storage.sol";
import "./MarginAccount.sol";
import "./SafeMathEx.sol";
import "./Error.sol";
import "./AMM.sol";


library Trade {

    using SignedSafeMath for int256;
    using SafeMathEx for int256;
    using MarginAccount for Storage.Perpetual;

    uint256 internal constant _MAX_PLAN_SIZE = 3;

    struct Recipe {
        int256[_MAX_PLAN_SIZE] plan;
        int256 takerOpeningAmount;
        int256 takerClosingAmount;
        int256 makerOpeningAmount;
        int256 makerClosingAmount;
    }

    function tradePosition(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public {
        require(positionAmount > 0, Error._ZERO_POSITION_AMOUNT);
        // trade
        Recipe memory recipe;
        _splitAmount(perpetual, context, recipe, positionAmount);
        _generateTradingPlan(perpetual, context, recipe, positionAmount);
        ( int256 totalCashCost, int256 totalFeeCost ) = _executeTradingPlan(perpetual, context, recipe);
        // validation
        int256 tradingPrice = totalCashCost.wdiv(positionAmount);
        require(tradingPrice > 0, Error._INVALID_TRADING_PRICE);
        require(_validatePrice(positionAmount, tradingPrice, priceLimit), Error._EXCEED_PRICE_LIMIT);
        // fee
        int256 tradingValue = tradingPrice.wmul(positionAmount);
        context.vaultFee = tradingValue.wmul(perpetual.settings.vaultFeeRate);
        context.operatorFee = tradingValue.wmul(perpetual.settings.operatorFeeRate);
        context.lpFee = totalFeeCost;
        context.tradingPrice = tradingPrice;
        // update margin account
        context.takerAccount.cashBalance = context.takerAccount.cashBalance
            .sub(totalCashCost)
            .sub(context.lpFee)
            .sub(context.vaultFee)
            .sub(context.operatorFee);
        context.makerAccount.cashBalance = context.makerAccount.cashBalance
            .add(totalCashCost);
        perpetual.updatePosition(context.takerAccount, recipe.takerClosingAmount, recipe.takerOpeningAmount);
        perpetual.updatePosition(context.makerAccount, recipe.makerClosingAmount, recipe.makerOpeningAmount);
        // safe check
        recipe.takerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.takerAccount) :
            perpetual.isMaintenanceMarginSafe(context.takerAccount);
        recipe.makerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.makerAccount) :
            perpetual.isMaintenanceMarginSafe(context.makerAccount);
    }

    function handleLiquidationLoss(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        int256 penaltyToLiquidator,
        int256 penaltyToFund
    ) internal view returns (int256) {
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

    function liquidate(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public returns (int256) {
        require(positionAmount > 0, Error._ZERO_POSITION_AMOUNT);
        tradePosition(perpetual, context, positionAmount, priceLimit);

        int256 liquidateValue = context.tradingPrice.wmul(positionAmount);
        int256 penaltyToLiquidator = perpetual.settings.liquidationGasReserve;
        int256 penaltyToLP = liquidateValue.wmul(perpetual.settings.liquidatorPenaltyRate);
        int256 penaltyToFund = liquidateValue.wmul(perpetual.settings.fundPenaltyRate);
        int256 socialLoss = handleLiquidationLoss(perpetual, context, penaltyToLP, penaltyToFund);
        // TODO: socialLoss > 0
        return penaltyToLiquidator;
    }

    function takePosition(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public {
        int256 takingPrice = perpetual.state.markPrice;
        require(_validatePrice(positionAmount, takingPrice, priceLimit), Error._EXCEED_PRICE_LIMIT);
        context.tradingPrice = takingPrice;
        Recipe memory recipe;
        _splitAmount(perpetual, context, recipe, positionAmount);

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
        recipe.makerOpeningAmount > 0 ?
            perpetual.isInitialMarginSafe(context.makerAccount) :
            perpetual.isMaintenanceMarginSafe(context.makerAccount);
    }

    function liquidate2(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        int256 positionAmount,
        int256 priceLimit
    ) public returns (int256) {
        require(positionAmount > 0, Error._ZERO_POSITION_AMOUNT);
        takePosition(perpetual, context, positionAmount, priceLimit);

        int256 liquidateValue = context.tradingPrice.wmul(positionAmount);
        int256 penaltyToLiquidator = perpetual.settings.liquidationGasReserve;
        int256 penaltyToLiquidator2 = liquidateValue.wmul(perpetual.settings.liquidatorPenaltyRate);
        int256 penaltyToFund = liquidateValue.wmul(perpetual.settings.fundPenaltyRate);
        int256 socialLoss = handleLiquidationLoss(perpetual, context, penaltyToLiquidator2, penaltyToFund);
        // TODO: socialLoss > 0
        return penaltyToLiquidator.add(penaltyToLiquidator2);
    }

    function _validatePrice(int256 positionAmount, int256 price, int256 priceLimit) internal pure returns (bool) {
        return positionAmount >= 0? price < priceLimit: price > priceLimit;
    }

    function _splitAmount(
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
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
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
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
        Storage.Perpetual storage perpetual,
        Storage.Context memory context,
        Recipe memory recipe
    ) internal returns (int256, int256) {
        int256 totalCashCost = 0;
        int256 totalFeeCost = 0;
        for (uint256 i = 0; i < _MAX_PLAN_SIZE; i++) {
            int256 tradingAmount = recipe.plan[i];
            if (tradingAmount == 0) {
                continue;
            }
            ( int256 cashCost, int256 feeCost ) = AMM.determineDeltaCashBalance(tradingAmount);
            totalCashCost = totalCashCost.add(cashCost);
            totalFeeCost = totalFeeCost.add(feeCost);
        }
        return (totalCashCost, totalFeeCost);
    }

}