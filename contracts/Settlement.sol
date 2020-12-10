// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./interface/IFactory.sol";
import "./interface/IShareToken.sol";

import "./module/AMMModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/CoreModule.sol";
import "./module/CollateralModule.sol";

import "./Storage.sol";
import "./Type.sol";

contract Settlement is Storage, ReentrancyGuardUpgradeable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SafeMathExt for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AddressUpgradeable for address;

    using OrderData for Order;
    using OrderModule for Core;

    using AMMModule for Core;
    using TradeModule for Core;
    using CoreModule for Core;
    using MarginModule for Market;
    using CollateralModule for Core;
    using SettlementModule for Core;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    function unclearedTraderCount(uint256 marketIndex) public view returns (uint256) {
        return _core.markets[marketIndex].registeredTraders.length();
    }

    function listUnclearedTraders(
        uint256 marketIndex,
        uint256 start,
        uint256 count
    ) public view returns (address[] memory result) {
        Market storage market = _core.markets[marketIndex];
        uint256 total = market.registeredTraders.length();
        if (start >= total) {
            return result;
        }
        uint256 stop = start.add(count).min(total);
        result = new address[](stop.sub(start));
        for (uint256 i = start; i < stop; i++) {
            result[i.sub(start)] = market.registeredTraders.at(i);
        }
    }

    function clear(uint256 marketIndex, address trader)
        public
        onlyWhen(marketIndex, MarketState.EMERGENCY)
        onlyExistedMarket(marketIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        _core.clear(marketIndex, trader);
    }

    function settle(uint256 marketIndex, address trader)
        public
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(marketIndex, MarketState.CLEARED)
        onlyExistedMarket(marketIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        _core.settle(marketIndex, trader);
    }

    bytes[50] private __gap;
}
