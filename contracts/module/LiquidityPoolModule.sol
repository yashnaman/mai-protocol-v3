// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IPoolCreator.sol";
import "../interface/IDecimals.sol";
import "../interface/IShareToken.sol";

import "./AMMModule.sol";
import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library LiquidityPoolModule {
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using OracleModule for LiquidityPoolStorage;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);
    event IncreaseFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);

    function initialize(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        address operator,
        address governor,
        address shareToken
    ) internal {
        require(collateral != address(0), "collateral is invalid");
        require(governor != address(0), "governor is invalid");
        require(shareToken != address(0), "shareToken is invalid");

        uint8 decimals = IDecimals(collateral).decimals();
        require(decimals <= MAX_COLLATERAL_DECIMALS, "collateral decimals is out of range");
        liquidityPool.collateral = collateral;
        liquidityPool.scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));

        liquidityPool.factory = msg.sender;
        IPoolCreator factory = IPoolCreator(liquidityPool.factory);
        liquidityPool.isWrapped = (collateral == factory.weth());
        liquidityPool.vault = factory.vault();
        liquidityPool.vaultFeeRate = factory.vaultFeeRate();
        liquidityPool.accessController = factory.accessController();

        liquidityPool.operator = operator;
        liquidityPool.shareToken = shareToken;
    }

    function addLiquidity(LiquidityPoolStorage storage liquidityPool, int256 cashAmount) public {
        int256 totalCashAmount = liquidityPool.transferFromUser(msg.sender, cashAmount);
        require(totalCashAmount > 0, "total cashAmount must be positive");
        int256 shareTotalSupply = IERC20Upgradeable(liquidityPool.shareToken)
            .totalSupply()
            .toInt256();
        int256 shareAmount = liquidityPool.getShareToMint(shareTotalSupply, totalCashAmount);
        require(shareAmount > 0, "received share must be positive");
        liquidityPool.poolCash = liquidityPool.poolCash.add(totalCashAmount);
        IShareToken(liquidityPool.shareToken).mint(msg.sender, shareAmount.toUint256());
        emit AddLiquidity(msg.sender, totalCashAmount, shareAmount);
    }

    function removeLiquidity(LiquidityPoolStorage storage liquidityPool, int256 shareToRemove)
        public
    {
        require(shareToRemove > 0, "share to remove must be positive");
        require(
            shareToRemove <=
                IERC20Upgradeable(liquidityPool.shareToken).balanceOf(msg.sender).toInt256(),
            "insufficient share balance"
        );
        int256 shareTotalSupply = IERC20Upgradeable(liquidityPool.shareToken)
            .totalSupply()
            .toInt256();
        int256 cashToReturn = liquidityPool.getCashToReturn(shareTotalSupply, shareToRemove);
        IShareToken(liquidityPool.shareToken).burn(msg.sender, shareToRemove.toUint256());
        liquidityPool.poolCash = liquidityPool.poolCash.sub(cashToReturn);
        liquidityPool.transferToUser(payable(msg.sender), cashToReturn);
        emit RemoveLiquidity(msg.sender, cashToReturn, shareToRemove);
    }

    function increaseFee(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        liquidityPool.claimableFees[account] = liquidityPool.claimableFees[account].add(amount);
        emit IncreaseFee(account, amount);
    }

    function claimFee(
        LiquidityPoolStorage storage liquidityPool,
        address claimer,
        int256 amount
    ) public {
        require(amount > 0, "invalid amount");
        require(amount <= liquidityPool.claimableFees[claimer], "insufficient fee");
        liquidityPool.claimableFees[claimer] = liquidityPool.claimableFees[claimer].sub(amount);
        liquidityPool.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }

    function rebalance(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual
    ) public {
        int256 rebalanceAmount = perpetual.getMargin(address(this), perpetual.getMarkPrice()).sub(
            perpetual.getInitialMargin(address(this), perpetual.getMarkPrice())
        );
        // TODO: if rebalanceAmount exceeds max collateral amount
        //
        transferCollateralToPool(liquidityPool, perpetual, rebalanceAmount);
    }

    function rebalanceAll(LiquidityPoolStorage storage liquidityPool) public {
        // int256 rebalanceAmount = perpetual.getMargin(address(this), perpetual.getMarkPrice()).sub(
        //     perpetual.getInitialMargin(address(this), perpetual.getMarkPrice())
        // );
        // // TODO: if rebalanceAmount exceeds max collateral amount
        // liquidityPool.poolCash +
        //     transferCollateralToPool(liquidityPool, perpetual, rebalanceAmount);
    }

    function transferCollateralToPool(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        liquidityPool.poolCash = liquidityPool.poolCash.add(amount);
        perpetual.collateralBalance = perpetual.collateralBalance.sub(amount);
    }

    function getRebalanceAmount(PerpetualStorage storage perpetual) public view returns (int256) {
        int256 markPrice = perpetual.getMarkPrice();
        return
            perpetual.getMargin(address(this), markPrice).sub(
                perpetual.getInitialMargin(address(this), markPrice)
            );
    }
}
