// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IPoolCreator.sol";
import "../interface/IDecimals.sol";
import "../interface/IShareToken.sol";

import "./AMMModule.sol";
import "./CollateralModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library LiquidityPoolModule {
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    using AMMModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);
    event IncreaseFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);
    event UpdatePoolMargin(int256 poolMargin);

    function getAvailablePoolCash(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256 availablePoolCash)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            if (perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            int256 markPrice = perpetual.getMarkPrice();
            availablePoolCash = availablePoolCash.add(
                perpetual.getMargin(address(this), markPrice).sub(
                    perpetual.getInitialMargin(address(this), markPrice)
                )
            );
        }
        return availablePoolCash.add(liquidityPool.poolCash);
    }

    function isMarginSafe(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (bool isSafe)
    {
        isSafe = (getAvailablePoolCash(liquidityPool) >= 0);
    }

    function initialize(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        address operator,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) public {
        require(collateral != address(0), "collateral is invalid");
        require(governor != address(0), "governor is invalid");
        require(shareToken != address(0), "shareToken is invalid");

        uint8 decimals = IDecimals(collateral).decimals();
        require(decimals <= MAX_COLLATERAL_DECIMALS, "collateral decimals is out of range");
        liquidityPool.collateralToken = collateral;
        liquidityPool.scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));

        liquidityPool.factory = msg.sender;
        IPoolCreator factory = IPoolCreator(liquidityPool.factory);
        liquidityPool.isWrapped = (collateral == factory.weth());
        liquidityPool.vault = factory.vault();
        liquidityPool.vaultFeeRate = factory.vaultFeeRate();
        liquidityPool.accessController = factory.accessController();

        liquidityPool.operator = operator;
        liquidityPool.shareToken = shareToken;
        liquidityPool.isFastCreationEnabled = isFastCreationEnabled;
    }

    function setParameter(
        LiquidityPoolStorage storage liquidityPool,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "isFastCreationEnabled") {
            liquidityPool.isFastCreationEnabled = (newValue != 0);
        } else {
            revert("key not found");
        }
    }

    function updateFundingState(LiquidityPoolStorage storage liquidityPool, uint256 currentTime)
        public
    {
        if (liquidityPool.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = currentTime.sub(liquidityPool.fundingTime).toInt256();
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updateFundingState(timeElapsed);
        }
        liquidityPool.fundingTime = currentTime;
    }

    function updateFundingRate(LiquidityPoolStorage storage liquidityPool) public {
        AMMModule.Context memory context = liquidityPool.prepareContext();
        (int256 poolMargin, bool isAMMSafe) = AMMModule.getPoolMargin(context);
        emit UpdatePoolMargin(poolMargin);
        if (!isAMMSafe) {
            poolMargin = 0;
        }
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updateFundingRate(poolMargin);
        }
    }

    function updatePrice(LiquidityPoolStorage storage liquidityPool, uint256 currentTime) internal {
        if (liquidityPool.priceUpdateTime >= currentTime) {
            return;
        }
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updatePrice();
        }
        liquidityPool.priceUpdateTime = currentTime;
    }

    function addLiquidity(LiquidityPoolStorage storage liquidityPool, int256 cashToAdd) public {
        int256 totalCashToAdd = liquidityPool.transferFromUser(msg.sender, cashToAdd);
        require(totalCashToAdd > 0, "total cash to add must be positive");

        IShareToken shareToken = IShareToken(liquidityPool.shareToken);
        int256 shareTotalSupply = shareToken.totalSupply().toInt256();
        int256 shareToMint = liquidityPool.getShareToMint(shareTotalSupply, totalCashToAdd);
        require(shareToMint > 0, "received share must be positive");
        shareToken.mint(msg.sender, shareToMint.toUint256());
        liquidityPool.poolCash = liquidityPool.poolCash.add(totalCashToAdd);
        emit AddLiquidity(msg.sender, totalCashToAdd, shareToMint);
    }

    function removeLiquidity(LiquidityPoolStorage storage liquidityPool, int256 shareToRemove)
        public
    {
        require(shareToRemove > 0, "share to remove must be positive");
        IShareToken shareToken = IShareToken(liquidityPool.shareToken);
        require(
            shareToRemove.toUint256() <= shareToken.balanceOf(msg.sender),
            "insufficient share balance"
        );

        int256 shareTotalSupply = shareToken.totalSupply().toInt256();
        int256 cashToReturn = liquidityPool.getCashToReturn(shareTotalSupply, shareToRemove);
        require(cashToReturn >= 0, "cash to return is negative");
        require(cashToReturn <= getAvailablePoolCash(liquidityPool), "insufficient pool cash");

        shareToken.burn(msg.sender, shareToRemove.toUint256());
        liquidityPool.transferToUser(payable(msg.sender), cashToReturn);
        decreasePoolCash(liquidityPool, cashToReturn);
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

    function rebalanceFrom(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual
    ) public {
        int256 rebalanceMargin = perpetual.getRebalanceMargin();
        if (rebalanceMargin == 0) {
            // nothing to rebalance
            return;
        } else if (rebalanceMargin > 0) {
            // from perp to pool
            perpetual.decreaseTotalCollateral(rebalanceMargin);
            increasePoolCash(liquidityPool, rebalanceMargin);
        } else {
            // from pool to perp
            int256 availablePoolCash = getAvailablePoolCash(liquidityPool);
            if (availablePoolCash < 0) {
                return;
            }
            rebalanceMargin = rebalanceMargin.abs().min(availablePoolCash);
            perpetual.increaseTotalCollateral(rebalanceMargin);
            decreasePoolCash(liquidityPool, rebalanceMargin);
        }
    }

    function increasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.add(amount);
    }

    function decreasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.sub(amount);
    }
}
