// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./ParameterModule.sol";
import "./OracleModule.sol";
import "./MarginModule.sol";
import "./CollateralModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

library PerpetualModule {
    using SignedSafeMathUpgradeable for int256;
    using SafeMathExt for int256;

    using CollateralModule for LiquidityPoolStorage;
    using ParameterModule for PerpetualStorage;
    using ParameterModule for Option;
    using MarginModule for PerpetualStorage;
    using OracleModule for PerpetualStorage;
    using SettlementModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);
    event DonateInsuranceFund(uint256 perpetualIndex, int256 amount);
    event EnterNormalState(uint256 perpetualIndex);
    event EnterEmergencyState(
        uint256 perpetualIndex,
        int256 settlementPrice,
        uint256 settlementTime
    );
    event EnterClearedState(uint256 perpetualIndex);

    function initialize(
        PerpetualStorage storage perpetual,
        uint256 id,
        address oracle,
        int256[9] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) public {
        perpetual.id = id;
        perpetual.oracle = oracle;

        perpetual.initialMarginRate = coreParams[0];
        perpetual.maintenanceMarginRate = coreParams[1];
        perpetual.operatorFeeRate = coreParams[2];
        perpetual.lpFeeRate = coreParams[3];
        perpetual.referrerRebateRate = coreParams[4];
        perpetual.liquidationPenaltyRate = coreParams[5];
        perpetual.keeperGasReward = coreParams[6];
        perpetual.insuranceFundRate = coreParams[7];
        perpetual.insuranceFundCap = coreParams[8];
        perpetual.validateCoreParameters();

        perpetual.halfSpread.setOption(riskParams[0], minRiskParamValues[0], maxRiskParamValues[0]);
        perpetual.openSlippageFactor.setOption(
            riskParams[1],
            minRiskParamValues[1],
            maxRiskParamValues[1]
        );
        perpetual.closeSlippageFactor.setOption(
            riskParams[2],
            minRiskParamValues[2],
            maxRiskParamValues[2]
        );
        perpetual.fundingRateLimit.setOption(
            riskParams[3],
            minRiskParamValues[3],
            maxRiskParamValues[3]
        );
        perpetual.ammMaxLeverage.setOption(
            riskParams[4],
            minRiskParamValues[4],
            maxRiskParamValues[4]
        );
        perpetual.validateRiskParameters();
        perpetual.state = PerpetualState.INITIALIZING;
    }

    function donateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 amount
    ) external {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 totalAmount = liquidityPool.transferFromUser(msg.sender, amount);
        require(totalAmount > 0, "total amount is 0");
        perpetual.donatedInsuranceFund = perpetual.donatedInsuranceFund.add(totalAmount);
        increaseCollateralAmount(perpetual, totalAmount);
        emit DonateInsuranceFund(perpetualIndex, totalAmount);
    }

    function deposit(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        bool isInitial = perpetual.isEmptyAccount(trader);
        int256 totalAmount = liquidityPool.transferFromUser(trader, amount);
        require(totalAmount > 0, "total amount is 0");
        perpetual.updateCash(trader, totalAmount);
        increaseCollateralAmount(perpetual, totalAmount);
        if (isInitial) {
            perpetual.registerActiveAccount(trader);
            IPoolCreator(liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
        emit Deposit(perpetualIndex, trader, totalAmount);
    }

    function withdraw(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        liquidityPool.rebalance(perpetual);
        perpetual.updateCash(trader, amount.neg());
        decreaseCollateralAmount(perpetual, amount);
        require(perpetual.isInitialMarginSafe(trader), "margin is unsafe after withdrawal");
        if (perpetual.isEmptyAccount(trader)) {
            perpetual.deregisterActiveAccount(trader);
            IPoolCreator(liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
        liquidityPool.transferToUser(payable(trader), amount);
        emit Withdraw(perpetualIndex, trader, amount);
    }

    function increaseCollateralAmount(PerpetualStorage storage perpetual, int256 amount) public {
        require(amount >= 0, "amount is negative");
        perpetual.collateralBalance = perpetual.collateralBalance.add(amount);
    }

    function decreaseCollateralAmount(PerpetualStorage storage perpetual, int256 amount) public {
        require(amount >= 0, "amount is negative");
        perpetual.collateralBalance = perpetual.collateralBalance.sub(amount);
        require(perpetual.collateralBalance >= 0, "collateral is negative");
    }

    function enterNormalState(PerpetualStorage storage perpetual) internal {
        require(
            perpetual.state == PerpetualState.INITIALIZING,
            "perpetual should be in initializing state"
        );
        perpetual.state = PerpetualState.NORMAL;
        emit EnterNormalState(perpetual.id);
    }

    function enterEmergencyState(PerpetualStorage storage perpetual) internal {
        require(perpetual.state == PerpetualState.NORMAL, "perpetual should be in normal state");
        perpetual.updatePrice();
        perpetual.freezePrice();
        perpetual.state = PerpetualState.EMERGENCY;
        emit EnterEmergencyState(
            perpetual.id,
            perpetual.settlementPriceData.price,
            perpetual.settlementPriceData.time
        );
    }

    function enterClearedState(PerpetualStorage storage perpetual) internal {
        require(perpetual.state == PerpetualState.EMERGENCY, "perpetual should be in normal state");
        perpetual.state = PerpetualState.CLEARED;
        emit EnterClearedState(perpetual.id);
    }

    function updateInsuranceFund(PerpetualStorage storage perpetual, int256 penaltyToFund)
        public
        returns (int256 penaltyToLP)
    {
        int256 newInsuranceFund = perpetual.insuranceFund;
        if (penaltyToFund == 0) {
            penaltyToLP = 0;
        } else if (perpetual.insuranceFund >= perpetual.insuranceFundCap) {
            penaltyToLP = penaltyToFund;
        } else if (penaltyToFund > 0) {
            newInsuranceFund = newInsuranceFund.add(penaltyToFund);
            if (newInsuranceFund > perpetual.insuranceFundCap) {
                newInsuranceFund = perpetual.insuranceFundCap;
                penaltyToLP = perpetual.insuranceFundCap.sub(newInsuranceFund);
            }
        } else {
            newInsuranceFund = newInsuranceFund.add(penaltyToFund);
            if (newInsuranceFund < 0) {
                perpetual.donatedInsuranceFund = perpetual.donatedInsuranceFund.add(
                    newInsuranceFund
                );
                newInsuranceFund = 0;
            }
        }
        perpetual.insuranceFund = newInsuranceFund;
    }
}
