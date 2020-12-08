// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./libraries/Error.sol";
import "./libraries/OrderData.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./interface/IFactory.sol";
import "./interface/IShareToken.sol";

import "./Type.sol";
import "./Storage.sol";
import "./module/AMMModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/CoreModule.sol";
import "./module/CollateralModule.sol";

import "./Events.sol";
import "./AccessControl.sol";

contract Settlement is Storage, AccessControl, ReentrancyGuardUpgradeable {
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
    using SettlementModule for Market;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    function unclearedTraderCount(bytes32 marketID) public view returns (uint256) {
        return _core.markets[marketID].registeredTraders.length();
    }

    function listUnclearedTraders(
        bytes32 marketID,
        uint256 start,
        uint256 count
    ) public view returns (address[] memory result) {
        Market storage market = _core.markets[marketID];
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

    function clearMarginAccount(bytes32 marketID, address trader)
        public
        onlyWhen(marketID, MarketState.EMERGENCY)
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        Market storage market = _core.markets[marketID];
        market.clearMarginAccount(trader);
        if (market.keeperGasReward > 0) {
            _core.transferToUser(msg.sender, market.keeperGasReward);
        }
        if (unclearedTraderCount(marketID) == 0) {
            market.updateWithdrawableMargin(0);
            _enterClearedState(marketID);
        }
        emit Clear(trader);
    }

    function settle(bytes32 marketID, address trader)
        public
        auth(trader, PRIVILEGE_WITHDRAW)
        onlyWhen(marketID, MarketState.CLEARED)
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        Market storage market = _core.markets[marketID];
        int256 withdrawable = market.settledMarginAccount(trader);
        market.updateCashBalance(trader, withdrawable.neg());
        _core.transferToUser(payable(trader), withdrawable);
        emit Withdraw(trader, withdrawable);
    }
}
