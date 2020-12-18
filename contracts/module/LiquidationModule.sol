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
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(trader), "trader is safe");
        Receipt memory receipt;
        int256 maxAmount = perpetual.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, "amount is invalid");
        // 0. price / amount
        (receipt.tradeValue, receipt.tradeAmount) = liquidityPool.tradeWithAMM(
            perpetualIndex,
            maxAmount,
            false
        );
        // 1. fee
        TradeModule.updateTradingFees(liquidityPool, perpetual, receipt, INVALID_ADDRESS);
        // 2. execute
        TradeModule.updateTradingResult(perpetual, receipt, trader, address(this));
        // 3. penalty
        int256 penaltyToFund = updateLiquidationPenalty(
            perpetual,
            trader,
            perpetual.markPrice().wmul(receipt.tradeAmount).wmul(perpetual.liquidationPenaltyRate),
            perpetual.keeperGasReward
        );
        liquidityPool.transferToUser(msg.sender, perpetual.keeperGasReward);
        // 4. events
        emit Liquidate(
            perpetualIndex,
            address(this),
            trader,
            receipt.tradeAmount,
            receipt.tradeValue.wdiv(receipt.tradeAmount).abs()
        );
        // 5. emergency
        bool isInsuranceFundDrained = updateInsuranceFund(liquidityPool, perpetual, penaltyToFund);
        if (isInsuranceFundDrained) {
            perpetual.enterEmergencyState();
        }
    }

    function liquidateByTrader(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address taker,
        address maker,
        int256 amount,
        int256 limitPrice
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(maker), "trader is safe");
        Receipt memory receipt;
        // 0. price / amountyo
        int256 tradingPrice = perpetual.markPrice();
        TradeModule.validatePrice(amount, tradingPrice, limitPrice);
        (receipt.tradeValue, receipt.tradeAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        bool isOpening = Utils.isOpening(perpetual.positionAmount(taker), amount);
        TradeModule.updateTradingResult(perpetual, receipt, taker, maker);
        // 2. penalty
        int256 penaltyToFund = updateLiquidationPenalty(
            perpetual,
            maker,
            receipt.tradeValue.wmul(perpetual.liquidationPenaltyRate),
            0
        );
        // 3. safe
        if (isOpening) {
            require(perpetual.isInitialMarginSafe(taker), "trader initial margin unsafe");
        } else {
            require(perpetual.isMaintenanceMarginSafe(taker), "trader maintenance margin unsafe");
        }
        // 4. events
        emit Liquidate(perpetualIndex, taker, maker, receipt.tradeAmount, tradingPrice);
        // 5. emergency
        bool isInsuranceFundDrained = updateInsuranceFund(liquidityPool, perpetual, penaltyToFund);
        if (isInsuranceFundDrained) {
            perpetual.enterEmergencyState();
        }
    }

    function updateLiquidationPenalty(
        PerpetualStorage storage perpetual,
        address trader,
        int256 softPenalty,
        int256 hardPenalty
    ) internal returns (int256 penaltyToFund) {
        int256 penaltyFromTrader;
        int256 penaltyToTaker;
        int256 fullPenalty = hardPenalty.add(softPenalty);
        int256 traderMargin = perpetual.margin(trader, perpetual.markPrice());
        penaltyFromTrader = fullPenalty.min(traderMargin);
        int256 effectivePenalty = penaltyFromTrader.sub(hardPenalty);
        if (effectivePenalty > 0) {
            penaltyToFund = effectivePenalty.wmul(perpetual.insuranceFundRate);
            penaltyToTaker = effectivePenalty.sub(penaltyToFund);
        } else {
            penaltyToFund = effectivePenalty;
            penaltyToTaker = 0;
        }
        perpetual.updateCashBalance(address(this), penaltyToTaker);
        perpetual.updateCashBalance(trader, penaltyFromTrader.neg());
        return penaltyToFund;
    }

    function updateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        int256 penalty
    ) internal returns (bool isInsuranceFundDrained) {
        int256 penaltyToFund;
        int256 penaltyToLP;
        if (
            penalty < 0 ||
            liquidityPool.insuranceFund.add(penalty) <= liquidityPool.insuranceFundCap
        ) {
            penaltyToFund = penalty;
            penaltyToLP = 0;
        } else if (liquidityPool.insuranceFund > liquidityPool.insuranceFundCap) {
            penaltyToLP = penalty;
        } else {
            int256 fundToFill = liquidityPool.insuranceFundCap.sub(liquidityPool.insuranceFund);
            penaltyToFund = fundToFill;
            penaltyToLP = penalty.sub(fundToFill);
        }
        return liquidityPool.updateInsuranceFund(perpetual, penaltyToFund);
    }
}
