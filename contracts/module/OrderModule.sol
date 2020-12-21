// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";

import "../module/MarginModule.sol";
import "../module/OracleModule.sol";

import "../Type.sol";

library OrderModule {
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using OrderData for Order;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    uint32 internal constant SUPPORTED_ORDER_VERSION = 3;

    event FillOrder(Order order, bytes32 orderHash, int256 filledAmount, int256 totalAmount);
    event CancelOrder(Order order, bytes32 orderHash);

    function validateOrder(
        LiquidityPoolStorage storage liquidityPool,
        Order memory order,
        int256 amount
    ) public view {
        // broker / relayer
        require(order.broker == msg.sender, "broker mismatch");
        require(order.relayer == tx.origin, "relayer mismatch");
        // pool / perpetual
        require(order.liquidityPool == address(this), "liquidity pool mismatch");
        require(
            order.perpetualIndex < liquidityPool.perpetuals.length,
            "perpetual index out of range"
        );
        // amount
        require(amount != 0 && Utils.hasSameSign(amount, order.amount), "invalid amount");
        require(order.amount != 0, "order amount is 0");
        require(amount.abs() >= order.minTradeAmount, "amount is less than min trade amount");
        require(amount.abs() <= order.amount.abs(), "amount exceeds order amount");
        // expire
        require(order.expiredAt >= block.timestamp, "order is expired");
        // chain id
        require(order.chainID == Utils.chainID(), "chainid mismatch");
        // close only
        require(
            !(order.isStopLossOrder() && order.isTakeProfitOrder()),
            "stop-loss order cannot be take-profit"
        );
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[order.perpetualIndex];
        int256 positionAmount = perpetual.positionAmount(order.trader);
        if (order.isCloseOnly()) {
            ensureCloseOnly(positionAmount, amount);
        }
        if (order.isStopLossOrder() || order.isTakeProfitOrder()) {
            ensureTriggerPrice(perpetual, order, positionAmount);
        }
    }

    function ensureCloseOnly(int256 positionAmount, int256 amount) internal pure {
        require(positionAmount != 0, "trader has no position to close");
        require(!Utils.hasSameSign(positionAmount, amount), "trader is not closing position");
    }

    function ensureTriggerPrice(
        PerpetualStorage storage perpetual,
        Order memory order,
        int256 positionAmount
    ) public view {
        int256 indexPrice = perpetual.indexPrice();
        if (
            (order.isStopLossOrder() && positionAmount > 0) ||
            (order.isTakeProfitOrder() && positionAmount < 0)
        ) {
            // stop-loss + long / take-profit + short
            require(indexPrice <= order.triggerPrice, "trigger price is not reached");
        } else if (
            (order.isStopLossOrder() && positionAmount < 0) ||
            (order.isTakeProfitOrder() && positionAmount > 0)
        ) {
            // stop-loss + long / take-profit + short
            require(indexPrice >= order.triggerPrice, "trigger price is not reached");
        }
    }

    function truncateCloseAmount(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) internal view returns (int256 truncatedAmount) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 positionAmount = perpetual.positionAmount(trader);
        truncatedAmount = amount.abs() > positionAmount.abs() ? positionAmount : amount;
    }
}
