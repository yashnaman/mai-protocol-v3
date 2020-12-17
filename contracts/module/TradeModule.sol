// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./CoreModule.sol";
import "./MarginModule.sol";
import "./OracleModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for Core;
    using CoreModule for Core;
    using MarginModule for Perpetual;
    using OracleModule for Perpetual;
    using MarginModule for MarginAccount;

    address internal constant INVALID_ADDRESS = address(0);

    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 positionAmount,
        int256 price,
        int256 fee
    );

    function trade(
        Core storage core,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public {
        Perpetual storage perpetual = core.perpetuals[perpetualIndex];
        // 0. price / amount
        Receipt memory receipt;
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            perpetualIndex,
            amount.neg(),
            false
        );
        bool isOpeningPosition = Utils.isOpeningPosition(
            perpetual.positionAmount(trader),
            receipt.tradingAmount.neg()
        );
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        validatePrice(receipt.tradingAmount.neg(), tradingPrice.abs(), priceLimit);
        // 1. fee
        updateTradingFees(core, perpetual, receipt, referrer);
        // 2. execute
        updateTradingResult(perpetual, receipt, trader, address(this));
        // 3. safe
        if (isOpeningPosition) {
            require(perpetual.isInitialMarginSafe(trader), "trader initial margin is unsafe");
        } else {
            require(perpetual.isMarginSafe(trader), "trader margin is unsafe");
        }
        // 4. event
        emit Trade(
            perpetualIndex,
            trader,
            receipt.tradingAmount,
            tradingPrice,
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(receipt.referrerFee)
        );
    }

    function updateTradingFees(
        Core storage core,
        Perpetual storage perpetual,
        Receipt memory receipt,
        address referrer
    ) public {
        int256 tradingValue = receipt.tradingValue.abs();
        receipt.vaultFee = tradingValue.wmul(core.vaultFeeRate);
        receipt.lpFee = tradingValue.wmul(perpetual.lpFeeRate);
        receipt.operatorFee = tradingValue.wmul(perpetual.operatorFeeRate);
        if (perpetual.referrerRebateRate > 0 && referrer != INVALID_ADDRESS) {
            int256 lpFeeRebate = receipt.lpFee.wmul(perpetual.referrerRebateRate);
            int256 operatorFeeRabate = receipt.operatorFee.wmul(perpetual.referrerRebateRate);
            receipt.lpFee = receipt.lpFee.sub(lpFeeRebate);
            receipt.operatorFee = receipt.operatorFee.sub(operatorFeeRabate);
            receipt.referrerFee = lpFeeRebate.add(operatorFeeRabate);
        }
        core.increaseClaimableFee(referrer, receipt.referrerFee);
        core.increaseClaimableFee(core.vault, receipt.vaultFee);
        core.increaseClaimableFee(core.operator, receipt.operatorFee);
    }

    function updateTradingResult(
        Perpetual storage perpetual,
        Receipt memory receipt,
        address taker,
        address maker
    ) internal {
        perpetual.updateMarginAccount(
            taker,
            receipt.tradingAmount.neg(),
            receipt
                .tradingValue
                .neg()
                .sub(receipt.lpFee)
                .sub(receipt.vaultFee)
                .sub(receipt.operatorFee)
                .sub(receipt.referrerFee)
        );
        perpetual.updateMarginAccount(
            maker,
            receipt.tradingAmount,
            receipt.tradingValue.add(receipt.lpFee)
        );
    }

    function validatePrice(
        int256 amount,
        int256 price,
        int256 priceLimit
    ) internal pure {
        require(price > 0, "price is 0");
        if (amount > 0) {
            require(price <= priceLimit, "price is too high");
        } else if (amount < 0) {
            require(price >= priceLimit, "price is too low");
        }
    }
}
