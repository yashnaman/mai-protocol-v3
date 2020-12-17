// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./CoreModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./OracleModule.sol";
import "./TradeModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

library LiquidationModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for Core;
    using CoreModule for Core;
    using MarginModule for Perpetual;
    using OracleModule for Perpetual;
    using PerpetualModule for Perpetual;
    using CollateralModule for Core;

    address internal constant INVALID_ADDRESS = address(0);

    event Liquidate(
        uint256 perpetualIndex,
        address indexed liquidator,
        address indexed trader,
        int256 amount,
        int256 price
    );

    function liquidateByAMM(
        Core storage core,
        uint256 perpetualIndex,
        address trader
    ) public returns (int256) {
        Perpetual storage perpetual = core.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(trader), "trader is safe");
        Receipt memory receipt;
        int256 maxAmount = perpetual.marginAccounts[trader].positionAmount;
        require(maxAmount != 0, "amount is invalid");
        // 0. price / amount
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            perpetualIndex,
            maxAmount,
            false
        );
        // 1. fee
        TradeModule.updateTradingFees(core, perpetual, receipt, INVALID_ADDRESS);
        // 2. execute
        TradeModule.updateTradingResult(perpetual, receipt, trader, address(this));
        // 3. penalty
        updateLiquidationPenalty(
            core,
            perpetual,
            trader,
            perpetual.markPrice().wmul(receipt.tradingAmount).wmul(
                perpetual.liquidationPenaltyRate
            ),
            perpetual.keeperGasReward
        );
        core.transferToUser(msg.sender, perpetual.keeperGasReward);
        // 4. events
        emit Liquidate(
            perpetualIndex,
            address(this),
            trader,
            receipt.tradingAmount,
            receipt.tradingValue.wdiv(receipt.tradingAmount).abs()
        );
        return perpetual.keeperGasReward;
    }

    function liquidateByTrader(
        Core storage core,
        uint256 perpetualIndex,
        address taker,
        address maker,
        int256 amount,
        int256 priceLimit
    ) public returns (int256) {
        Perpetual storage perpetual = core.perpetuals[perpetualIndex];
        require(!perpetual.isMaintenanceMarginSafe(maker), "trader is safe");
        Receipt memory receipt;
        // 0. price / amountyo
        int256 tradingPrice = perpetual.markPrice();
        bool isOpeningPosition = Utils.isOpeningPosition(perpetual.positionAmount(taker), amount);
        TradeModule.validatePrice(amount, tradingPrice, priceLimit);
        (receipt.tradingValue, receipt.tradingAmount) = (tradingPrice.wmul(amount), amount);
        // 1. execute
        TradeModule.updateTradingResult(perpetual, receipt, taker, maker);
        // 2. penalty
        updateLiquidationPenalty(
            core,
            perpetual,
            maker,
            receipt.tradingValue.wmul(perpetual.liquidationPenaltyRate),
            0
        );
        // 3. safe
        if (isOpeningPosition) {
            require(perpetual.isInitialMarginSafe(taker), "trader initial margin unsafe");
        } else {
            require(perpetual.isMaintenanceMarginSafe(taker), "trader maintenance margin unsafe");
        }
        // 6. events
        emit Liquidate(perpetualIndex, taker, maker, receipt.tradingAmount, tradingPrice.abs());
        return 0;
    }

    function updateLiquidationPenalty(
        Core storage core,
        Perpetual storage perpetual,
        address trader,
        int256 softPenalty,
        int256 hardPenalty
    ) internal {
        int256 penaltyFromTrader;
        int256 penaltyToFund;
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
        updateInsuranceFund(core, penaltyToFund);
        if (core.donatedInsuranceFund < 0) {
            perpetual.enterEmergencyState();
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
