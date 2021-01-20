// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./libraries/Constant.sol";
import "./libraries/OrderData.sol";

import "./module/TradeModule.sol";
import "./module/OrderModule.sol";
import "./module/LiquidityPoolModule.sol";

import "./Storage.sol";
import "./Type.sol";

contract Perpetual is Storage, ReentrancyGuardUpgradeable {
    using OrderData for bytes;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using OrderModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;

    /**
     * @notice Donate collateral to the insurance fund of the perpetual. Can only called when the perpetual's
     *         state is "NORMAL". Can improve the security of the perpetual
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param amount The amount of collateral to donate
     */
    function donateInsuranceFund(uint256 perpetualIndex, int256 amount)
        external
        payable
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
    {
        require(amount > 0, "amount is negative");
        _liquidityPool.donateInsuranceFund(perpetualIndex, amount);
    }

    /**
     * @notice Deposit collateral to the trader's account of the perpetual. Can only called when the perpetual's
     *         state is "NORMAL". The trader's cash will increase in the perpetual
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The amount of collatetal to deposit
     */
    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) external payable onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.deposit(perpetualIndex, trader, amount);
    }

    /**
     * @notice Withdraw collateral from the trader's account of the perpetual. Can only called when the perpetual's
     *         state is "NORMAL". Trader must be initial margin safe in the perpetual after withdrawing.
     *         The trader's cash will decrease in the perpetual.
     *         Need to update the funding state and the oracle price of each perpetual before
     *         and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The amount of collatetal to withdraw
     */
    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    )
        external
        syncState
        onlyNotPaused(perpetualIndex)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");
        _liquidityPool.withdraw(perpetualIndex, trader, amount);
    }

    /**
     * @notice If the state of the perpetual is "CLEARED", anyone authorized withdraw privilege by trader can settle
     *         trader's account in the perpetual. Which means to calculate how much the collateral should be returned
     *         to the trader, return it to trader's wallet and clear the trader's cash and position in the perpetual
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     */
    function settle(uint256 perpetualIndex, address trader)
        public
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.CLEARED)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        _liquidityPool.settle(perpetualIndex, trader);
    }

    /**
     * @notice Clear the next active account of the perpetual which state is "EMERGENCY" and send gas reward of collateral
     *         to sender. If all active accounts are cleared, the clear progress is done and the perpetual's state will
     *         change to "CLEARED". Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function clear(uint256 perpetualIndex)
        public
        onlyWhen(perpetualIndex, PerpetualState.EMERGENCY)
        nonReentrant
    {
        _liquidityPool.clear(perpetualIndex);
    }

    /**
     * @notice Trade with AMM in the perpetual, require sender is granted the trade privilege by the trader.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of trader
     * @param amount The position amount of the trade
     * @param limitPrice The worst price the trader accepts
     * @param deadline The deadline of the trade
     * @param referrer The referrer's address of the trade
     * @param flags The flags of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        uint32 flags
    ) external onlyAuthorized(trader, Constant.PRIVILEGE_TRADE) returns (int256) {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        return _trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    /**
     * @notice Trade with AMM by the order, initiated by the broker.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param orderData The order data object
     * @param amount The position amount of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function brokerTrade(bytes memory orderData, int256 amount)
        external
        returns (int256)
    {
        Order memory order = orderData.decodeOrderData();
        bytes memory signature = orderData.decodeSignature();
        _liquidityPool.validateSignature(order, signature);
        _liquidityPool.validateOrder(order, amount);
        _liquidityPool.validateTriggerPrice(order);
        return
            _trade(
                order.perpetualIndex,
                order.trader,
                amount,
                order.limitPrice,
                order.referrer,
                order.flags
            );
    }

    /**
     * @dev Trade with AMM in the perpetual. Need to update the funding state and the oracle price of each perpetual
     *      before and update the funding rate of each perpetual after. Can only called when the perpetual's state
     *      is "NORMAL" and the perpetual is not paused
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The position amount of the trade
     * @param limitPrice The worst price the trader accepts
     * @param referrer The referrer's address of trade
     * @param flags The flags of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function _trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    )
        internal
        syncState
        onlyNotPaused(perpetualIndex)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        returns (int256)
    {
        return _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    /**
     * @notice Liquidate the trader if the trader is not maintenance margin safe. AMM takes the position.
     *         The liquidate price is determied by AMM. The liquidator gets the keeper gas reward.
     *         If there is penalty, AMM and the insurance fund will taker it. If there is loss,
     *         the insurance fund will cover it. If the insurance fund including the donated part is negative,
     *         the perpetual's state should enter "EMERGENCY".
     *         Need to update the funding state and the oracle price of each perpetual before and
     *         update the funding rate of each perpetual after. Can only liquidate when the perpetual's state
     *         is "NORMAL"
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the liquidated trader
     * @return int256 The update position amount of the liquidated trader after the liquidation
     */
    function liquidateByAMM(uint256 perpetualIndex, address trader)
        external
        syncState
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
        returns (int256)
    {
        require(trader != address(0), "trader is invalid");
        require(trader != address(this), "cannot liquidate amm");
        return _liquidityPool.liquidateByAMM(perpetualIndex, msg.sender, trader);
    }

    /**
     * @notice Liquidate the trader if the trader is not maintenance margin safe. The liquidate price is mark price.
     *         If there is penalty, The liquidator and the insurance fund will taker it. If there is loss, the
     *         insurance fund will cover it. If the insurance fund including the donated part is negative, the perpetual's
     *         state should enter "EMERGENCY". The liquidator should be initial margin safe after the liquidation if
     *         he has opened position. If not, he should be maintenance margin safe.
     *         Need to update the funding state and the oracle price of each perpetual before and
     *         update the funding rate of each perpetual after. Can only liquidate when the perpetual's state
     *         is "NORMAL"
     * @param perpetualIndex The index of perpetual
     * @param trader The address of liquidated trader
     * @param amount The amount of liquidation
     * @param limitPrice The worst price liquidator accepts
     * @param deadline The deadline of liquidation
     * @return int256 The delta position of liquidated trader
     */
    function liquidateByTrader(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline
    )
        external
        syncState
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
        returns (int256)
    {
        require(trader != address(0), "trader is invalid");
        require(trader != address(this), "cannot liquidate amm");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        return
            _liquidityPool.liquidateByTrader(
                perpetualIndex,
                msg.sender,
                trader,
                amount,
                limitPrice
            );
    }

    bytes[50] private __gap;
}
