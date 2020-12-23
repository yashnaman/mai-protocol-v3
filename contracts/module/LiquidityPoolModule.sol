// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IPoolCreator.sol";
import "../interface/IDecimals.sol";

import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library LiquidityPoolModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using CollateralModule for LiquidityPoolStorage;
    using OracleModule for LiquidityPoolStorage;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    event DonateInsuranceFund(address trader, int256 amount);
    event IncreaseClaimableFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);

    function donateInsuranceFund(LiquidityPoolStorage storage liquidityPool, int256 amount)
        external
    {
        int256 totalAmount = liquidityPool.transferFromUser(msg.sender, amount);
        require(totalAmount > 0, "total amount is 0");
        liquidityPool.donatedInsuranceFund = liquidityPool.donatedInsuranceFund.add(totalAmount);
        liquidityPool.poolCollateralAmount = liquidityPool.poolCollateralAmount.add(totalAmount);
        emit DonateInsuranceFund(msg.sender, totalAmount);
    }

    function initialize(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        address operator,
        address governor,
        address shareToken,
        int256 insuranceFundCap
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
        liquidityPool.insuranceFundCap = insuranceFundCap;
    }

    function collectFee(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address referrer,
        int256 vaultFee,
        int256 operatorFee,
        int256 referrerFee
    ) public {
        require(vaultFee >= 0, "negative vault fee");
        require(operatorFee >= 0, "negative operator fee");
        require(referrerFee >= 0, "negative referrer fee");
        liquidityPool.claimableFees[liquidityPool.vault] = liquidityPool.claimableFees[liquidityPool
            .vault]
            .add(vaultFee);
        liquidityPool.claimableFees[liquidityPool.operator] = liquidityPool
            .claimableFees[liquidityPool.operator]
            .add(operatorFee);
        liquidityPool.claimableFees[referrer] = liquidityPool.claimableFees[referrer].add(
            referrerFee
        );
        int256 totalFee = vaultFee.add(operatorFee).add(referrerFee);
        liquidityPool.totalClaimableFee = liquidityPool.totalClaimableFee.add(totalFee);
        transferCollateralToPool(liquidityPool, perpetual, totalFee);
    }

    function claimFee(
        LiquidityPoolStorage storage liquidityPool,
        address claimer,
        int256 amount
    ) public {
        require(amount > 0, "invalid amount");
        require(amount <= liquidityPool.claimableFees[claimer], "insufficient fee");
        liquidityPool.claimableFees[claimer] = liquidityPool.claimableFees[claimer].sub(amount);
        liquidityPool.totalClaimableFee = liquidityPool.totalClaimableFee.sub(amount);
        liquidityPool.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }

    function updateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        int256 penaltyToFund,
        int256 penaltyToLP
    ) public returns (bool isInsuranceFundDrained) {
        if (penaltyToFund == 0) {
            isInsuranceFundDrained = false;
        } else if (penaltyToFund > 0) {
            // earning
            liquidityPool.insuranceFund = liquidityPool.insuranceFund.add(penaltyToFund);

            isInsuranceFundDrained = false;
        } else {
            int256 transferAmount = penaltyToFund;
            int256 newInsuranceFund = liquidityPool.insuranceFund.add(penaltyToFund);
            if (newInsuranceFund < 0) {
                // then donatedInsuranceFund will cover such loss
                int256 newDonatedInsuranceFund = liquidityPool.donatedInsuranceFund.add(
                    newInsuranceFund
                );
                liquidityPool.insuranceFund = 0;
                if (newDonatedInsuranceFund < 0) {
                    transferAmount = penaltyToFund.sub(newDonatedInsuranceFund);
                    isInsuranceFundDrained = true;
                    newDonatedInsuranceFund = 0;
                }
                liquidityPool.donatedInsuranceFund = newDonatedInsuranceFund;
            }
            liquidityPool.insuranceFund = newInsuranceFund;
            transferCollateralToPool(liquidityPool, perpetual, transferAmount);
        }
        liquidityPool.poolCashBalance = liquidityPool.poolCashBalance.add(penaltyToLP);
        transferCollateralToPool(liquidityPool, perpetual, penaltyToFund.add(penaltyToLP));
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
        // liquidityPool.poolCashBalance +
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
        liquidityPool.poolCollateralAmount = liquidityPool.poolCollateralAmount.add(amount);
        perpetual.collateralAmount = perpetual.collateralAmount.sub(amount);
    }

    function getRebalanceAmount(PerpetualStorage storage perpetual) public view returns (int256) {
        int256 markPrice = perpetual.getMarkPrice();
        return
            perpetual.getMargin(address(this), markPrice).sub(
                perpetual.getInitialMargin(address(this), markPrice)
            );
    }
}
