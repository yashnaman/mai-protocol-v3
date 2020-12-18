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
import "./libraries/Utils.sol";

import "./interface/IAccessController.sol";
import "./interface/IFactory.sol";
import "./interface/IShareToken.sol";

import "./module/AMMModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/LiquidationModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./Storage.sol";
import "./Type.sol";

import "hardhat/console.sol";

contract Perpetual is Storage, Events, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using OrderData for Order;

    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using LiquidationModule for LiquidityPoolStorage;
    using MarginModule for LiquidityPoolStorage;
    using OrderModule for LiquidityPoolStorage;
    using SettlementModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    )
        external
        payable
        onlyAuthorized(trader, Constant.PRIVILEGE_DEPOSTI)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.deposit(perpetualIndex, trader, amount);
    }

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");
        _liquidityPool.withdraw(perpetualIndex, trader, amount);
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_TRADE)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
    {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        if (isCloseOnly) {
            amount = _liquidityPool.truncateCloseAmount(perpetualIndex, trader, amount);
        }
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer);
    }

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature
    ) external syncState onlyWhen(order.perpetualIndex, PerpetualState.NORMAL) {
        address signer = order.signer(signature, false);
        require(
            signer == order.trader ||
                IAccessController(_liquidityPool.accessController).isGranted(
                    order.trader,
                    signer,
                    Constant.PRIVILEGE_TRADE
                ),
            "signer is unauthorized"
        );
        _liquidityPool.validateOrder(order, amount);
        if (order.isCloseOnly()) {
            amount = _liquidityPool.truncateCloseAmount(order.perpetualIndex, order.trader, amount);
        }
        _liquidityPool.trade(
            order.perpetualIndex,
            order.trader,
            amount,
            order.limitPrice,
            order.referrer
        );
    }

    function liquidateByAMM(
        uint256 perpetualIndex,
        address trader,
        uint256 deadline
    ) external syncState onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _liquidityPool.liquidateByAMM(perpetualIndex, trader);
    }

    function liquidateByTrader(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline
    ) external syncState onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _liquidityPool.liquidateByTrader(perpetualIndex, msg.sender, trader, amount, limitPrice);
    }

    bytes[50] private __gap;
}
