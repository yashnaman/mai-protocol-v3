// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using OrderData for uint32;

    using AMMModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for MarginAccount;
    using CollateralModule for LiquidityPoolStorage;

    address internal constant INVALID_ADDRESS = address(0);

    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 position,
        int256 price,
        int256 fee
    );
    event Liquidate(
        uint256 perpetualIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );

    function trade(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer,
        uint32 flags
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        amount = flags.isCloseOnly() ? getMaxPositionToClose(position, amount) : amount;
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount.neg(), false);

        console.log("{DEBUG}", uint256(deltaCash), uint256(deltaPosition));

        int256 tradePrice = deltaCash.wdiv(deltaPosition).abs();
        if (!flags.isMarketOrder()) {
            validatePrice(amount >= 0, tradePrice, priceLimit);
        }
        // 2. trade
        (int256 lpFee, int256 totalFee) =
            updateFees(liquidityPool, perpetual, deltaCash.abs(), referrer);
        perpetual.updateMargin(address(this), deltaPosition, deltaCash.add(lpFee));
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg().sub(totalFee));
        // 4. safe
        if (Utils.isOpen(position, deltaPosition.neg())) {
            require(
                perpetual.isInitialMarginSafe(trader, perpetual.getMarkPrice()),
                "trader initial margin is unsafe"
            );
        } else {
            require(
                perpetual.isMarginSafe(trader, perpetual.getMarkPrice()),
                "trader margin is unsafe"
            );
        }
        emit Trade(perpetualIndex, trader, deltaPosition.neg(), tradePrice, totalFee);
        return deltaPosition.neg();
    }

    function updateFees(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        int256 tradeValue,
        address referrer
    ) public returns (int256 lpFee, int256 totalFee) {
        require(tradeValue >= 0, "negative trade value");

        int256 vaultFee = tradeValue.wmul(liquidityPool.vaultFeeRate);
        int256 operatorFee = tradeValue.wmul(perpetual.operatorFeeRate);
        lpFee = tradeValue.wmul(perpetual.lpFeeRate);
        totalFee = vaultFee.add(operatorFee).add(lpFee);

        if (referrer != INVALID_ADDRESS && perpetual.referrerRebateRate > 0) {
            int256 lpFeeRebate = lpFee.wmul(perpetual.referrerRebateRate);
            int256 operatorFeeRabate = operatorFee.wmul(perpetual.referrerRebateRate);
            int256 referrerFee = lpFeeRebate.add(operatorFeeRabate);
            lpFee = lpFee.sub(lpFeeRebate);
            operatorFee = operatorFee.sub(operatorFeeRabate);
            liquidityPool.transferToUser(payable(referrer), referrerFee);
        }

        liquidityPool.transferToUser(payable(liquidityPool.vault), vaultFee);
        liquidityPool.increaseFee(liquidityPool.operator, operatorFee);
        perpetual.decreaseTotalCollateral(totalFee);
    }

    function liquidateByAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 amount = perpetual.getPosition(trader);
        int256 markPrice = perpetual.getMarkPrice();
        require(!perpetual.isMaintenanceMarginSafe(trader, markPrice), "trader is safe");
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) =
            liquidityPool.queryTradeWithAMM(perpetualIndex, amount, false);
        // 2. trade
        int256 liquidatePrice = deltaCash.wdiv(deltaPosition).abs();
        perpetual.updateMargin(address(this), deltaPosition, deltaCash);
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg());
        // 3. penalty
        {
            int256 liquidatePenalty =
                perpetual
                    .getMarkPrice()
                    .wmul(deltaPosition)
                    .wmul(perpetual.liquidationPenaltyRate)
                    .abs();
            (int256 penaltyToTaker, int256 penaltyToFund) =
                getLiquidationPenalty(
                    perpetual,
                    trader,
                    liquidatePenalty,
                    perpetual.keeperGasReward
                );
            require(penaltyToTaker >= 0, "penalty to taker should be greater equal than 0");
            int256 penaltyToLP = perpetual.updateInsuranceFund(penaltyToFund);
            perpetual.updateCash(address(this), penaltyToTaker.add(penaltyToLP));
            liquidityPool.transferToUser(payable(liquidator), perpetual.keeperGasReward);
        }
        emit Liquidate(perpetualIndex, address(this), trader, deltaPosition.neg(), liquidatePrice);
        // 4. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    function liquidateByTrader(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice
    ) public returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        amount = getMaxPositionToClose(position, amount);
        int256 markPrice = perpetual.getMarkPrice();
        require(!perpetual.isMaintenanceMarginSafe(trader, markPrice), "trader is safe");
        // 0. price / amountyo
        int256 liquidatePrice = markPrice;
        validatePrice(amount >= 0, liquidatePrice, limitPrice);
        (int256 deltaCash, int256 deltaPosition) = (liquidatePrice.wmul(amount), amount.neg());
        // 1. execute
        perpetual.updateMargin(trader, deltaPosition, deltaCash);
        perpetual.updateMargin(liquidator, deltaPosition.neg(), deltaCash.neg());
        // 2. penalty
        {
            int256 liquidatePenalty = deltaCash.wmul(perpetual.liquidationPenaltyRate).abs();
            (int256 penaltyToTaker, int256 penaltyToFund) =
                getLiquidationPenalty(perpetual, trader, liquidatePenalty, 0);
            require(penaltyToTaker >= 0, "penalty to taker should be greater than 0");
            int256 penaltyToLP = perpetual.updateInsuranceFund(penaltyToFund);
            perpetual.updateCash(liquidator, penaltyToTaker);
            perpetual.updateCash(address(this), penaltyToLP);
        }
        // 3. safe
        if (Utils.isOpen(perpetual.getPosition(liquidator), amount)) {
            require(
                perpetual.isInitialMarginSafe(liquidator, markPrice),
                "trader initial margin unsafe"
            );
        } else {
            require(
                perpetual.isMaintenanceMarginSafe(liquidator, markPrice),
                "trader maintenance margin unsafe"
            );
        }
        // 4. events
        emit Liquidate(perpetualIndex, liquidator, trader, deltaPosition.neg(), liquidatePrice);
        // 5. emergency
        if (perpetual.donatedInsuranceFund < 0) {
            liquidityPool.setEmergencyState(perpetualIndex);
        }
        return deltaPosition.neg();
    }

    function getMaxPositionToClose(int256 position, int256 amount)
        internal
        pure
        returns (int256 maxPositionToClose)
    {
        require(position != 0, "trader has no position to close");
        require(!Utils.hasTheSameSign(position, amount), "trader must be close only");
        maxPositionToClose = amount.abs() > position.abs() ? position : amount;
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 priceLimit
    ) internal pure {
        require(price >= 0, "negative price");
        bool isPriceSatisfied = isLong ? price <= priceLimit : price >= priceLimit;
        require(isPriceSatisfied, "price exceeds limit");
    }

    function getLiquidationPenalty(
        PerpetualStorage storage perpetual,
        address trader,
        int256 softPenalty,
        int256 hardPenalty
    ) internal view returns (int256 penaltyToTaker, int256 penaltyToFund) {
        require(softPenalty >= 0, "soft penalty is negative");
        require(hardPenalty >= 0, "hard penalty is negative");
        int256 fullPenalty = hardPenalty.add(softPenalty);
        int256 traderMargin = perpetual.getMargin(trader, perpetual.getMarkPrice());
        int256 traderMarginLeft = fullPenalty.min(traderMargin).sub(hardPenalty);
        if (traderMarginLeft > 0) {
            penaltyToFund = traderMarginLeft.wmul(perpetual.insuranceFundRate);
            penaltyToTaker = traderMarginLeft.sub(penaltyToFund);
        } else {
            penaltyToFund = traderMarginLeft;
            penaltyToTaker = 0;
        }
    }
}
