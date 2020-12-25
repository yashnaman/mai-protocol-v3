// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./LiquidityPoolModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";

import "../Type.sol";

library TradeModule {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for MarginAccount;

    address internal constant INVALID_ADDRESS = address(0);

    event Trade(
        uint256 perpetualIndex,
        address indexed trader,
        int256 position,
        int256 price,
        int256 fee
    );

    function trade(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        address referrer,
        bool isCloseOnly
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 position = perpetual.getPosition(trader);
        if (isCloseOnly) {
            require(position != 0, "trader has no position to close");
            require(!Utils.hasTheSameSign(position, amount), "trader must be close only");
            amount = amount.abs() > position.abs() ? position : amount;
        }
        // 0. price / amount
        (int256 deltaCash, int256 deltaPosition) = liquidityPool.queryTradeWithAMM(
            perpetualIndex,
            amount.neg(),
            false
        );
        int256 tradePrice = deltaCash.wdiv(deltaPosition).abs();
        validatePrice(amount >= 0, tradePrice, priceLimit);
        // 2. trade
        (int256 lpFee, int256 totalFee) = updateFees(
            liquidityPool,
            perpetual,
            deltaCash.abs(),
            referrer
        );
        bool isOpen = Utils.isOpen(position, deltaPosition.neg());
        perpetual.updateMargin(address(this), deltaPosition, deltaCash.add(lpFee));
        perpetual.updateMargin(trader, deltaPosition.neg(), deltaCash.neg().sub(totalFee));
        // 4. safe
        if (isOpen) {
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
        emit Trade(perpetualIndex, trader, deltaPosition, tradePrice, totalFee);
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
            liquidityPool.increaseFee(referrer, referrerFee);
        }

        liquidityPool.increaseFee(liquidityPool.vault, vaultFee);
        liquidityPool.increaseFee(liquidityPool.operator, operatorFee);
        // [perpetual fee] => [pool claimable]
        perpetual.decreaseTotalCollateral(totalFee);
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 priceLimit
    ) internal view {
        console.log("[DEBUG]", isLong, uint256(price), uint256(priceLimit));

        require(price >= 0, "negative price");
        bool isPriceSatisfied = isLong ? price <= priceLimit : price >= priceLimit;
        require(isPriceSatisfied, "price exceeds limit");
    }
}
