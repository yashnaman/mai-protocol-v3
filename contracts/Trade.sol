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
import "./module/CoreModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./Storage.sol";
import "./Type.sol";

import "hardhat/console.sol";

contract Trade is Storage, Events, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using OrderData for Order;

    using AMMModule for Core;
    using CollateralModule for Core;
    using CoreModule for Core;
    using LiquidationModule for Core;
    using MarginModule for Core;
    using OrderModule for Core;
    using SettlementModule for Core;
    using TradeModule for Core;

    function deposit(
        uint256 marketIndex,
        address trader,
        int256 amount
    )
        external
        payable
        onlyAuthorized(trader, Constant.PRIVILEGE_DEPOSTI)
        onlyWhen(marketIndex, MarketState.NORMAL)
        onlyExistedMarket(marketIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");
        _core.deposit(marketIndex, trader, amount.add(msg.value.toInt256()));
    }

    function withdraw(
        uint256 marketIndex,
        address trader,
        int256 amount
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(marketIndex, MarketState.NORMAL)
        onlyExistedMarket(marketIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");
        _core.withdraw(marketIndex, trader, amount);
    }

    function trade(
        uint256 marketIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    )
        external
        syncState
        onlyAuthorized(trader, Constant.PRIVILEGE_TRADE)
        onlyWhen(marketIndex, MarketState.NORMAL)
    {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(priceLimit >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        if (isCloseOnly) {
            amount = _core.truncateAmount(marketIndex, trader, amount);
        }
        _core.trade(marketIndex, trader, amount, priceLimit, referrer);
    }

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature
    ) external {
        address signer = order.signer(signature);
        require(
            signer == order.trader ||
                IAccessController(_core.accessController).isGranted(
                    order.trader,
                    signer,
                    Constant.PRIVILEGE_TRADE
                ),
            "unauthorized"
        );
        _core.validateOrder(order, amount);
        if (order.isCloseOnly() || order.orderType() == OrderType.STOP) {
            amount = _core.truncateAmount(order.marketIndex, order.trader, amount);
        }
        _core.trade(order.marketIndex, order.trader, amount, order.priceLimit, order.referrer);
    }

    function liquidateByAMM(
        uint256 marketIndex,
        address trader,
        uint256 deadline
    ) external syncState onlyWhen(marketIndex, MarketState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _core.liquidateByAMM(marketIndex, trader);
    }

    function liquidateByTrader(
        uint256 marketIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline
    ) external syncState onlyWhen(marketIndex, MarketState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(priceLimit >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        _core.liquidateByTrader(marketIndex, msg.sender, trader, amount, priceLimit);
    }

    bytes[50] private __gap;
}
