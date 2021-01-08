// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./libraries/Constant.sol";
import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";

import "./module/AMMModule.sol";
import "./module/MarginAccountModule.sol";
import "./module/TradeModule.sol";
import "./module/OrderModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";
import "./module/CollateralModule.sol";
import "./module/SignatureModule.sol";

import "./Storage.sol";
import "./Type.sol";

contract Perpetual is Storage, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using OrderData for bytes;

    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;
    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using OrderModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;
    using SignatureModule for bytes32;

    /**
     * @notice Donate collateral to insurance fund of perpetual
     * @param perpetualIndex The index of perpetual
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
     * @notice Deposit collateral to account of perpetual
     * @param perpetualIndex The index of perpetual
     * @param trader The address of trader
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
     * @notice Withdraw collateral from account of perpetual
     * @param perpetualIndex The index of perpetual
     * @param trader The address of trader
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
     * @notice Settle account of perpetual
     * @param perpetualIndex The index of perpetual
     * @param trader The address of trader
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
     * @notice Clear perpetual
     * @param perpetualIndex The index of perpetual
     */
    function clear(uint256 perpetualIndex)
        public
        onlyWhen(perpetualIndex, PerpetualState.EMERGENCY)
        nonReentrant
    {
        _liquidityPool.clear(perpetualIndex);
    }

    /**
     * @notice Trade in perpetual, require trader to have trade privilege
     * @param perpetualIndex The index of perpetual
     * @param trader The address of trader
     * @param amount The amount of trade
     * @param limitPrice The worst price trader accepts
     * @param deadline The deadline of trade
     * @param referrer The referrer of trade
     * @param flags The flags of trade
     * @return int256 The delta position of trader
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
     * @notice Trade with amm by order, initiated by broker
     * @param orderData The order
     * @param amount The amount of trade
     * @return int256 The delta position of trader
     */
    function brokerTrade(bytes memory orderData, int256 amount)
        external
        syncState
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
     * @dev Trade with amm
     * @param perpetualIndex The index of perpetual
     * @param trader The address of trader
     * @param amount The position amount of trade
     * @param limitPrice The worst price trader accepts
     * @param referrer The referrer of trade
     * @param flags The flags of trade
     * @return int256 The delta position of trader
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
     * @notice Liquidate trader if trader is unsafe, amm takes position
     * @param perpetualIndex The index of perpetual
     * @param trader The address of liquidated trader
     * @param deadline The deadline of liquidation
     * @return int256 The delta position of liquidated trader
     */
    function liquidateByAMM(
        uint256 perpetualIndex,
        address trader,
        uint256 deadline
    )
        external
        syncState
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
        returns (int256)
    {
        require(trader != address(0), "trader is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        return _liquidityPool.liquidateByAMM(perpetualIndex, msg.sender, trader);
    }

    /**
     * @notice Liquidate trader if trader is unsafe, liquidator takes position
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
