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
    using MarginModule for Market;
    using OracleModule for Market;
    using MarginModule for MarginAccount;

    address internal constant INVALID_ADDRESS = address(0);

    event Trade(
        uint256 marketIndex,
        address indexed trader,
        int256 positionAmount,
        int256 price,
        int256 fee
    );

    function trade(
        Core storage core,
        uint256 marketIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer
    ) public {
        Market storage market = core.markets[marketIndex];
        // 0. price / amount
        Receipt memory receipt;
        (receipt.tradingValue, receipt.tradingAmount) = core.tradeWithAMM(
            marketIndex,
            amount.neg(),
            false
        );
        bool isOpeningPosition = Utils.isOpeningPosition(
            market.positionAmount(trader),
            receipt.tradingAmount.neg()
        );
        int256 tradingPrice = receipt.tradingValue.wdiv(receipt.tradingAmount);
        validatePrice(receipt.tradingAmount.neg(), tradingPrice.abs(), priceLimit);
        // 1. fee
        updateTradingFees(core, market, receipt, referrer);
        // 2. execute
        updateTradingResult(market, receipt, trader, address(this));
        // 3. safe
        if (isOpeningPosition) {
            require(market.isInitialMarginSafe(trader), "trader initial margin is unsafe");
        } else {
            require(market.isMarginSafe(trader), "trader margin is unsafe");
        }
        // 4. event
        emit Trade(
            marketIndex,
            trader,
            receipt.tradingAmount,
            tradingPrice,
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(receipt.referrerFee)
        );
    }

    function updateTradingFees(
        Core storage core,
        Market storage market,
        Receipt memory receipt,
        address referrer
    ) public {
        int256 tradingValue = receipt.tradingValue.abs();
        receipt.vaultFee = tradingValue.wmul(core.vaultFeeRate);
        receipt.lpFee = tradingValue.wmul(market.lpFeeRate);
        receipt.operatorFee = tradingValue.wmul(market.operatorFeeRate);
        if (market.referrerRebateRate > 0 && referrer != INVALID_ADDRESS) {
            int256 lpFeeRebate = receipt.lpFee.wmul(market.referrerRebateRate);
            int256 operatorFeeRabate = receipt.operatorFee.wmul(market.referrerRebateRate);
            receipt.lpFee = receipt.lpFee.sub(lpFeeRebate);
            receipt.operatorFee = receipt.operatorFee.sub(operatorFeeRabate);
            receipt.referrerFee = lpFeeRebate.add(operatorFeeRabate);
        }
        core.increaseClaimableFee(referrer, receipt.referrerFee);
        core.increaseClaimableFee(core.vault, receipt.vaultFee);
        core.increaseClaimableFee(core.operator, receipt.operatorFee);
    }

    function updateTradingResult(
        Market storage market,
        Receipt memory receipt,
        address taker,
        address maker
    ) internal {
        market.updateMarginAccount(
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
        market.updateMarginAccount(
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
