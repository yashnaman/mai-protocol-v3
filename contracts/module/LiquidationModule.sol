// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./CoreModule.sol";
import "./MarginModule.sol";
import "./MarketModule.sol";
import "./OracleModule.sol";
import "./TradeModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

library LiquidationModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for Core;
    using CoreModule for Core;
    using MarginModule for Market;
    using OracleModule for Market;
    using MarketModule for Market;
    using CollateralModule for Core;

    address internal constant INVALID_ADDRESS = address(0);

    event ClosePositionByLiquidation(
        address trader,
        int256 amount,
        int256 price,
        int256 fundingLoss
    );
    event OpenPositionByLiquidation(address trader, int256 amount, int256 price);
    event Liquidate(
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );

    function liquidateByAMM(
        Core storage core,
        uint256 marketIndex,
        address trader
    ) public returns (int256) {
        Market storage market = core.markets[marketIndex];
        require(!market.isMaintenanceMarginSafe(trader), "trader is safe");
        Receipt memory receipt;
        int256 maxAmount = market.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, "amount is invalid");
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            marketIndex,
            maxAmount,
            false
        );
        // 1. fee
        TradeModule.updateTradingFees(core, market, receipt, INVALID_ADDRESS);
        // 2. execute
        TradeModule.updateTradingResult(market, receipt, trader, address(this));
        // 3. penalty
        updateLiquidationPenalty(
            core,
            market,
            trader,
            receipt.tradingValue.wmul(market.liquidationPenaltyRate),
            market.keeperGasReward
        );
        core.transferToUser(msg.sender, market.keeperGasReward);
        // 4. events
        emit Liquidate(
            address(this),
            trader,
            receipt.tradingAmount,
            receipt.tradingValue.wdiv(receipt.tradingAmount).abs()
        );
        return market.keeperGasReward;
    }

    function liquidateByTrader(
        Core storage core,
        uint256 marketIndex,
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public returns (int256) {
        Market storage market = core.markets[marketIndex];
        require(!market.isMaintenanceMarginSafe(maker), "trader is safe");
        Receipt memory receipt;
        // 0. price / amountyo
        int256 tradingPrice = market.markPrice();
        bool isOpeningPosition = Utils.isOpeningPosition(market.positionAmount(taker), amount);
        TradeModule.validatePrice(amount, tradingPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        TradeModule.updateTradingResult(market, receipt, taker, maker);
        // 2. penalty
        updateLiquidationPenalty(
            core,
            market,
            maker,
            receipt.tradingValue.wmul(market.liquidationPenaltyRate),
            0
        );
        // 3. safe
        if (isOpeningPosition) {
            require(market.isInitialMarginSafe(taker), "trader initial margin unsafe");
        } else {
            require(market.isMaintenanceMarginSafe(taker), "trader maintenance margin unsafe");
        }
        // 6. events
        emit Liquidate(taker, maker, receipt.tradingAmount, tradingPrice.abs());
        return 0;
    }

    function updateLiquidationPenalty(
        Core storage core,
        Market storage market,
        address trader,
        int256 softPenalty,
        int256 hardPenalty
    ) internal {
        int256 penaltyFromTrader;
        int256 penaltyToFund;
        int256 penaltyToTaker;
        int256 fullPenalty = hardPenalty.add(softPenalty);
        int256 traderMargin = market.margin(trader, market.markPrice());
        penaltyFromTrader = fullPenalty.min(traderMargin);
        int256 effectivePenalty = penaltyFromTrader.sub(hardPenalty);
        if (effectivePenalty > 0) {
            penaltyToFund = effectivePenalty.wmul(market.insuranceFundRate);
            penaltyToTaker = effectivePenalty.sub(penaltyToFund);
        } else {
            penaltyToFund = effectivePenalty;
            penaltyToTaker = 0;
        }
        market.updateCashBalance(address(this), penaltyToTaker);
        market.updateCashBalance(trader, penaltyFromTrader.neg());
        updateInsuranceFund(core, penaltyToFund);
        if (core.donatedInsuranceFund < 0) {
            market.enterEmergencyState();
        }
    }

    function updateInsuranceFund(Core storage core, int256 penalty) internal {
        int256 penaltyToFund;
        int256 penaltyToLP;
        if (penalty < 0 || core.insuranceFund.add(penalty) <= core.insuranceFundCap) {
            penaltyToFund = penalty;
            penaltyToLP = 0;
        } else if (core.insuranceFund > core.insuranceFundCap) {
            penaltyToLP = penalty;
        } else {
            int256 fundToFill = core.insuranceFundCap.sub(core.insuranceFund);
            penaltyToFund = fundToFill;
            penaltyToLP = penalty.sub(fundToFill);
        }
        core.insuranceFund = core.insuranceFund.add(core.insuranceFund);
        // but fundGain could be negative in worst case
        if (core.insuranceFund < 0) {
            // then donatedInsuranceFund will cover such loss
            core.donatedInsuranceFund = core.donatedInsuranceFund.add(core.insuranceFund);
            core.insuranceFund = 0;
        }
    }
}
