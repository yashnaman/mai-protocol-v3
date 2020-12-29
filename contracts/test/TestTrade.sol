// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";
import "../module/TradeModule.sol";

import "../Type.sol";
import "./TestMarginAccount.sol";

contract TestTrade is TestMarginAccount {
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;
    using TradeModule for PerpetualStorage;

    function setOperator(address operator) public {
        _liquidityPool.operator = operator;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _liquidityPool.vault = vault;
        _liquidityPool.vaultFeeRate = vaultFeeRate;
    }

    function debugTrade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    function debugBrokerTrade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    function updateFees(
        uint256 perpetualIndex,
        int256 value,
        address referrer
    ) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.updateFees(perpetual, value, referrer);
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 limitPrice
    ) public view {
        TradeModule.validatePrice(isLong, price, limitPrice);
    }

    function updateFee(
        uint256 perpetualIndex,
        int256 tradeValue,
        address referrer
    ) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        _liquidityPool.updateFees(perpetual, tradeValue, referrer);
    }

    function getClaimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }
}
