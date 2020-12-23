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

import "./interface/IPoolCreator.sol";
import "./interface/IShareToken.sol";

import "./module/AMMModule.sol";
import "./module/MarginModule.sol";
import "./module/TradeModule.sol";
import "./module/SettlementModule.sol";
import "./module/OrderModule.sol";
import "./module/LiquidityPoolModule.sol";
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
    using OrderModule for LiquidityPoolStorage;

    using AMMModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using MarginModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;
    using SettlementModule for LiquidityPoolStorage;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    function getClearProgress(uint256 perpetualIndex)
        public
        view
        returns (uint256 left, uint256 total)
    {
        left = _liquidityPool.perpetuals[perpetualIndex].activeAccounts.length();
        total = _liquidityPool.perpetuals[perpetualIndex].clearedTraders.length().add(left);
    }

    function getSettleableMargin(uint256 perpetualIndex, address trader)
        public
        returns (int256 margin)
    {
        margin = _liquidityPool.getSettleableMargin(perpetualIndex, trader);
    }

    function clear(uint256 perpetualIndex)
        public
        onlyWhen(perpetualIndex, PerpetualState.EMERGENCY)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        address unclearedAccount = _liquidityPool.getAccountToClear(perpetualIndex);
        _liquidityPool.clearAccount(perpetualIndex, unclearedAccount);
    }

    function settle(uint256 perpetualIndex, address trader)
        public
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.CLEARED)
        onlyExistedPerpetual(perpetualIndex)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        _liquidityPool.settleAccount(perpetualIndex, trader);
    }

    bytes[50] private __gap;
}
