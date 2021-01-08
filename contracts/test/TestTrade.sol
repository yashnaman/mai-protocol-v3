// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";
import "../module/TradeModule.sol";

import "../Type.sol";
import "./TestLiquidityPool.sol";

contract TestTrade is TestLiquidityPool {
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for LiquidityPoolStorage;
    using TradeModule for LiquidityPoolStorage;
    using TradeModule for PerpetualStorage;

    function setVault(address vault, int256 vaultFeeRate) public {
        _liquidityPool.vault = vault;
        _liquidityPool.vaultFeeRate = vaultFeeRate;
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    function brokerTrade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public syncState {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    function getFees(
        uint256 perpetualIndex,
        address trader,
        int256 tradeValue
    )
        public
        view
        returns (
            int256 lpFee,
            int256 operatorFee,
            int256 vaultFee
        )
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        (lpFee, operatorFee, vaultFee) = _liquidityPool.getFees(perpetual, trader, tradeValue);
    }

    function updateFees(
        uint256 perpetualIndex,
        address trader,
        address referrer,
        int256 value
    ) public returns (int256 lpFee, int256 totalFee) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return _liquidityPool.updateFees(perpetual, trader, referrer, value);
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 limitPrice
    ) public pure {
        TradeModule.validatePrice(isLong, price, limitPrice);
    }

    function getClaimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }
}
