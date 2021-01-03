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

    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (int256 cash, int256 position)
    {
        MarginAccount storage account =
            _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader];
        cash = account.cash;
        position = account.position;
    }

    function getClearProgress(uint256 perpetualIndex)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (uint256 left, uint256 total)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        left = perpetual.activeAccounts.length();
        total = perpetual.clearedTraders.length().add(left);
    }

    function getSettleableMargin(uint256 perpetualIndex, address trader)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (int256 settleableMargin)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        int256 markPrice = perpetual.getMarkPrice();
        settleableMargin = perpetual.getSettleableMargin(trader, markPrice);
    }

    function donateInsuranceFund(uint256 perpetualIndex, int256 amount)
        external
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
    {
        require(amount > 0, "amount is negative");
        int256 totalAmount = _liquidityPool.transferFromUser(msg.sender, amount);
        _liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(totalAmount);
    }

    // function deposit(
    //     uint256 perpetualIndex,
    //     address trader,
    //     int256 amount
    // ) external payable onlyAuthorized(trader, Constant.PRIVILEGE_DEPOSTI) {
    //     _deposit(perpetualIndex, trader, amount);
    // }

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bytes32 extData,
        bytes calldata signature
    ) external payable onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount > 0 || msg.value > 0, "amount is invalid");
        address signer =
            SignatureModule.EIP712_TYPED_DEPOSIT.parseExtData(
                extData,
                abi.encode(perpetualIndex, trader, amount),
                signature
            );
        require(
            _liquidityPool.isAuthorized(trader, signer, Constant.PRIVILEGE_DEPOSTI),
            "unauthorized signer"
        );
        int256 totalAmount = _liquidityPool.transferFromUser(trader, amount);
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        if (perpetual.deposit(trader, totalAmount)) {
            IPoolCreator(_liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
    }

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bytes32 extData,
        bytes calldata signature
    )
        external
        syncState
        onlyNotPaused(perpetualIndex)
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        require(amount > 0, "amount is invalid");
        address signer =
            SignatureModule.EIP712_TYPED_DEPOSIT.parseExtData(
                extData,
                abi.encode(perpetualIndex, trader, amount),
                signature
            );
        require(
            _liquidityPool.isAuthorized(trader, signer, Constant.PRIVILEGE_DEPOSTI),
            "unauthorized signer"
        );
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.rebalanceFrom(perpetual);
        if (perpetual.withdraw(trader, amount)) {
            IPoolCreator(_liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
        _liquidityPool.transferToUser(payable(trader), amount);
    }

    function clear(
        uint256 perpetualIndex,
        bytes32 extData,
        bytes calldata signature
    ) public onlyWhen(perpetualIndex, PerpetualState.EMERGENCY) nonReentrant {
        address signer =
            SignatureModule.EIP712_TYPED_DEPOSIT.parseExtData(
                extData,
                abi.encode(perpetualIndex),
                signature
            );
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        if (perpetual.clear(perpetual.getNextDirtyAccount())) {
            int256 marginToReturn = perpetual.settle(address(this));
            perpetual.decreaseTotalCollateral(marginToReturn);
            _liquidityPool.increasePoolCash(marginToReturn);
        }
        if (perpetual.totalCollateral >= perpetual.keeperGasReward) {
            perpetual.decreaseTotalCollateral(perpetual.keeperGasReward);
            _liquidityPool.transferToUser(payable(signer), perpetual.keeperGasReward);
        }
    }

    function settle(
        uint256 perpetualIndex,
        address trader,
        bytes32 extData,
        bytes calldata signature
    )
        public
        onlyAuthorized(trader, Constant.PRIVILEGE_WITHDRAW)
        onlyWhen(perpetualIndex, PerpetualState.CLEARED)
        nonReentrant
    {
        require(trader != address(0), "trader is invalid");
        address signer =
            SignatureModule.EIP712_TYPED_DEPOSIT.parseExtData(
                extData,
                abi.encode(perpetualIndex, trader),
                signature
            );
        require(
            _liquidityPool.isAuthorized(trader, signer, Constant.PRIVILEGE_DEPOSTI),
            "unauthorized signer"
        );
        int256 marginToReturn = _liquidityPool.perpetuals[perpetualIndex].settle(trader);
        _liquidityPool.transferToUser(payable(trader), marginToReturn);
    }

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
