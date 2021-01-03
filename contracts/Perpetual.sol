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

    function donateInsuranceFund(uint256 perpetualIndex, int256 amount)
        external
        payable
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
    {
        require(amount > 0, "amount is negative");
        _liquidityPool.donateInsuranceFund(perpetualIndex, amount);
    }

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bytes32 extData,
        bytes calldata signature
    ) external payable onlyWhen(perpetualIndex, PerpetualState.NORMAL) nonReentrant {
        require(trader != address(0), "trader is invalid");
        require(amount > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.deposit(perpetualIndex, trader, amount, extData, signature);
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
        _liquidityPool.withdraw(perpetualIndex, trader, amount, extData, signature);
    }

    function clear(
        uint256 perpetualIndex,
        bytes32 extData,
        bytes calldata signature
    ) public onlyWhen(perpetualIndex, PerpetualState.EMERGENCY) nonReentrant {
        _liquidityPool.clear(perpetualIndex, extData, signature);
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
            SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
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
        address liquidator,
        address trader,
        uint256 deadline,
        bytes32 extData,
        bytes calldata signature
    )
        external
        syncState
        onlyWhen(perpetualIndex, PerpetualState.NORMAL)
        nonReentrant
        returns (int256)
    {
        require(trader != address(0), "trader is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        address signer =
            SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
                extData,
                abi.encode(perpetualIndex, liquidator, trader, deadline),
                signature
            );
        require(
            _liquidityPool.isAuthorized(trader, signer, Constant.PRIVILEGE_DEPOSTI),
            "unauthorized signer"
        );
        return _liquidityPool.liquidateByAMM(perpetualIndex, msg.sender, trader);
    }

    function liquidateByTrader(
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        bytes32 extData,
        bytes calldata signature
    ) external nonReentrant returns (int256) {
        require(trader != address(0), "trader is invalid");
        require(amount != 0, "amount is invalid");
        require(limitPrice >= 0, "price limit is invalid");
        require(deadline >= block.timestamp, "deadline exceeded");
        {
            address signer =
                SignatureModule.EIP712_TYPED_DEPOSIT.getSigner(
                    extData,
                    abi.encode(perpetualIndex, liquidator, trader, deadline),
                    signature
                );
            require(
                _liquidityPool.isAuthorized(trader, signer, Constant.PRIVILEGE_DEPOSTI),
                "unauthorized signer"
            );
        }
        return _liquidateByTrader(perpetualIndex, liquidator, trader, amount, limitPrice);
    }

    function _liquidateByTrader(
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice
    ) internal syncState onlyWhen(perpetualIndex, PerpetualState.NORMAL) returns (int256) {
        return
            _liquidityPool.liquidateByTrader(
                perpetualIndex,
                liquidator,
                trader,
                amount,
                limitPrice
            );
    }

    bytes[50] private __gap;
}
