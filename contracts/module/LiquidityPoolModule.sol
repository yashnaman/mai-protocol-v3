// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";
import "../interface/IDecimals.sol";

import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

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
        emit DonateInsuranceFund(msg.sender, totalAmount);
    }

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
        IFactory factory = IFactory(liquidityPool.factory);
        liquidityPool.isWrapped = (collateral == factory.weth());
        liquidityPool.vault = factory.vault();
        liquidityPool.vaultFeeRate = factory.vaultFeeRate();
        liquidityPool.accessController = factory.accessController();

        liquidityPool.operator = operator;
        liquidityPool.shareToken = shareToken;
    }

    function collectFee(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        address referrer,
        int256 vaultFee,
        int256 operatorFee,
        int256 referrerFee
    ) public {
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
        require(amount <= liquidityPool.claimableFees[claimer], "insufficient fee");
        liquidityPool.claimableFees[claimer] = liquidityPool.claimableFees[claimer].sub(amount);
        liquidityPool.totalClaimableFee = liquidityPool.totalClaimableFee.sub(amount);
        liquidityPool.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }

    function updateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual,
        int256 amount
    ) public returns (bool isInsuranceFundDrained) {
        if (amount == 0) {
            return false;
        } else if (amount > 0) {
            // earning
            liquidityPool.insuranceFund = liquidityPool.insuranceFund.add(amount);
            transferCollateralToPool(liquidityPool, perpetual, amount);
            return false;
        } else {
            int256 transferAmount = amount;
            int256 newInsuranceFund = liquidityPool.insuranceFund.add(amount);
            if (newInsuranceFund < 0) {
                // then donatedInsuranceFund will cover such loss
                int256 newDonatedInsuranceFund = liquidityPool.donatedInsuranceFund.add(
                    newInsuranceFund
                );
                liquidityPool.insuranceFund = 0;
                if (newDonatedInsuranceFund < 0) {
                    transferAmount = amount.sub(newDonatedInsuranceFund);
                    isInsuranceFundDrained = true;
                    newDonatedInsuranceFund = 0;
                }
                liquidityPool.donatedInsuranceFund = newDonatedInsuranceFund;
            }
            liquidityPool.insuranceFund = newInsuranceFund;
            transferCollateralToPool(liquidityPool, perpetual, transferAmount);
        }
    }

    function rebalance(
        LiquidityPoolStorage storage liquidityPool,
        PerpetualStorage storage perpetual
    ) public {
        int256 rebalancingAmount = perpetual.margin(address(this), perpetual.markPrice()).sub(
            perpetual.initialMargin(address(this), perpetual.markPrice())
        );
        transferCollateralToPool(liquidityPool, perpetual, rebalancingAmount);
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
}
