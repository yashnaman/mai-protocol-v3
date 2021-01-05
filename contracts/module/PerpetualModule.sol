// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../interface/IOracle.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./MarginAccountModule.sol";
import "./CollateralModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library PerpetualModule {
    using SignedSafeMathUpgradeable for int256;
    using SafeMathExt for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using CollateralModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    event Deposit(uint256 perpetualIndex, address trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address trader, int256 amount);
    event Clear(uint256 perpetualIndex, address trader);
    event Settle(uint256 perpetualIndex, address trader, int256 amount);
    event DonateInsuranceFund(uint256 perpetualIndex, int256 amount);
    event SetNormalState(uint256 perpetualIndex);
    event SetEmergencyState(uint256 perpetualIndex, int256 settlementPrice, uint256 settlementTime);
    event SetClearedState(uint256 perpetualIndex);
    event UpdateUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding);
    event SetPerpetualBaseParameter(uint256 perpetualIndex, bytes32 key, int256 value);
    event SetPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 value,
        int256 minValue,
        int256 maxValue
    );
    event UpdatePerpetualRiskParameter(uint256 perpetualIndex, bytes32 key, int256 value);

    function getMarkPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.markPriceData.price
                : perpetual.settlementPriceData.price;
    }

    function getIndexPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.indexPriceData.price
                : perpetual.settlementPriceData.price;
    }

    function getRebalanceMargin(PerpetualStorage storage perpetual)
        public
        view
        returns (int256 marginToRebalance)
    {
        int256 price = getMarkPrice(perpetual);
        marginToRebalance = perpetual.getMargin(address(this), price).sub(
            perpetual.getInitialMargin(address(this), price)
        );
    }

    function initialize(
        PerpetualStorage storage perpetual,
        uint256 id,
        address oracle,
        int256[9] calldata coreParams,
        int256[6] calldata riskParams,
        int256[6] calldata minRiskParamValues,
        int256[6] calldata maxRiskParamValues
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
        validateBaseParameters(perpetual);

        setOption(
            perpetual.halfSpread,
            riskParams[0],
            minRiskParamValues[0],
            maxRiskParamValues[0]
        );
        setOption(
            perpetual.openSlippageFactor,
            riskParams[1],
            minRiskParamValues[1],
            maxRiskParamValues[1]
        );
        setOption(
            perpetual.closeSlippageFactor,
            riskParams[2],
            minRiskParamValues[2],
            maxRiskParamValues[2]
        );
        setOption(
            perpetual.fundingRateLimit,
            riskParams[3],
            minRiskParamValues[3],
            maxRiskParamValues[3]
        );
        setOption(
            perpetual.ammMaxLeverage,
            riskParams[4],
            minRiskParamValues[4],
            maxRiskParamValues[4]
        );
        setOption(
            perpetual.maxClosePriceDiscount,
            riskParams[5],
            minRiskParamValues[5],
            maxRiskParamValues[5]
        );
        validateRiskParameters(perpetual);
        perpetual.state = PerpetualState.INITIALIZING;
    }

    function setBaseParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "initialMarginRate") {
            require(
                newValue < perpetual.initialMarginRate,
                "increasing initial margin rate is not allowed"
            );
            perpetual.initialMarginRate = newValue;
        } else if (key == "maintenanceMarginRate") {
            require(
                newValue < perpetual.maintenanceMarginRate,
                "increasing maintenance margin rate is not allowed"
            );
            perpetual.maintenanceMarginRate = newValue;
        } else if (key == "operatorFeeRate") {
            perpetual.operatorFeeRate = newValue;
        } else if (key == "lpFeeRate") {
            perpetual.lpFeeRate = newValue;
        } else if (key == "liquidationPenaltyRate") {
            perpetual.liquidationPenaltyRate = newValue;
        } else if (key == "keeperGasReward") {
            perpetual.keeperGasReward = newValue;
        } else if (key == "referrerRebateRate") {
            perpetual.referrerRebateRate = newValue;
        } else if (key == "insuranceFundRate") {
            perpetual.insuranceFundRate = newValue;
        } else if (key == "insuranceFundCap") {
            perpetual.insuranceFundCap = newValue;
        } else {
            revert("key not found");
        }
        emit SetPerpetualBaseParameter(perpetual.id, key, newValue);
    }

    function setRiskParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) public {
        if (key == "halfSpread") {
            setOption(perpetual.halfSpread, newValue, newMinValue, newMaxValue);
        } else if (key == "openSlippageFactor") {
            setOption(perpetual.openSlippageFactor, newValue, newMinValue, newMaxValue);
        } else if (key == "closeSlippageFactor") {
            setOption(perpetual.closeSlippageFactor, newValue, newMinValue, newMaxValue);
        } else if (key == "fundingRateLimit") {
            setOption(perpetual.fundingRateLimit, newValue, newMinValue, newMaxValue);
        } else if (key == "ammMaxLeverage") {
            setOption(perpetual.ammMaxLeverage, newValue, newMinValue, newMaxValue);
        } else if (key == "maxClosePriceDiscount") {
            setOption(perpetual.maxClosePriceDiscount, newValue, newMinValue, newMaxValue);
        } else {
            revert("key not found");
        }
        emit SetPerpetualRiskParameter(perpetual.id, key, newValue, newMinValue, newMaxValue);
    }

    function updateRiskParameter(
        PerpetualStorage storage perpetual,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "halfSpread") {
            updateOption(perpetual.halfSpread, newValue);
        } else if (key == "openSlippageFactor") {
            updateOption(perpetual.openSlippageFactor, newValue);
        } else if (key == "closeSlippageFactor") {
            updateOption(perpetual.closeSlippageFactor, newValue);
        } else if (key == "fundingRateLimit") {
            updateOption(perpetual.fundingRateLimit, newValue);
        } else if (key == "ammMaxLeverage") {
            updateOption(perpetual.ammMaxLeverage, newValue);
        } else if (key == "maxClosePriceDiscount") {
            updateOption(perpetual.maxClosePriceDiscount, newValue);
        } else {
            revert("key not found");
        }
        emit UpdatePerpetualRiskParameter(perpetual.id, key, newValue);
    }

    function updateFundingState(PerpetualStorage storage perpetual, int256 timeElapsed) public {
        int256 deltaUnitLoss =
            getIndexPrice(perpetual).wfrac(
                perpetual.fundingRate.wmul(timeElapsed),
                FUNDING_INTERVAL
            );
        perpetual.unitAccumulativeFunding = perpetual.unitAccumulativeFunding.add(deltaUnitLoss);
        emit UpdateUnitAccumulativeFunding(perpetual.id, perpetual.unitAccumulativeFunding);
    }

    function updateFundingRate(PerpetualStorage storage perpetual, int256 poolMargin) public {
        int256 newFundingRate = 0;
        int256 position = perpetual.getPosition(address(this));
        if (position != 0) {
            int256 fundingRateLimit = perpetual.fundingRateLimit.value;
            if (poolMargin != 0) {
                newFundingRate = getIndexPrice(perpetual).wfrac(position, poolMargin).neg().wmul(
                    perpetual.fundingRateLimit.value
                );
                newFundingRate = newFundingRate > fundingRateLimit
                    ? fundingRateLimit
                    : newFundingRate;
                newFundingRate = newFundingRate < fundingRateLimit.neg()
                    ? fundingRateLimit.neg()
                    : newFundingRate;
            } else if (position > 0) {
                newFundingRate = fundingRateLimit.neg();
            } else {
                newFundingRate = fundingRateLimit;
            }
        }
        perpetual.fundingRate = newFundingRate;
    }

    function setNormalState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.INITIALIZING,
            "perpetual should be in initializing state"
        );
        perpetual.state = PerpetualState.NORMAL;
        emit SetNormalState(perpetual.id);
    }

    function setEmergencyState(PerpetualStorage storage perpetual) public {
        require(perpetual.state == PerpetualState.NORMAL, "perpetual should be in normal state");
        // use mark price as final price when emergency
        perpetual.settlementPriceData = perpetual.markPriceData;
        perpetual.totalAccount = perpetual.activeAccounts.length();
        perpetual.state = PerpetualState.EMERGENCY;
        emit SetEmergencyState(
            perpetual.id,
            perpetual.settlementPriceData.price,
            perpetual.settlementPriceData.time
        );
    }

    function setClearedState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.EMERGENCY,
            "perpetual should be in emergency state"
        );
        settleCollateral(perpetual);
        perpetual.state = PerpetualState.CLEARED;
        emit SetClearedState(perpetual.id);
    }

    function donateInsuranceFund(PerpetualStorage storage perpetual, int256 amount) public {
        require(amount > 0, "amount should greater than 0");
        perpetual.donatedInsuranceFund = perpetual.donatedInsuranceFund.add(amount);
        increaseTotalCollateral(perpetual, amount);
        emit DonateInsuranceFund(perpetual.id, amount);
    }

    function deposit(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isInitialDeposit) {
        require(amount > 0, "amount should greater than 0");
        isInitialDeposit = perpetual.isEmptyAccount(trader);
        perpetual.updateCash(trader, amount);
        increaseTotalCollateral(perpetual, amount);
        if (isInitialDeposit) {
            registerActiveAccount(perpetual, trader);
        }
        emit Deposit(perpetual.id, trader, amount);
    }

    function withdraw(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isLastWithdrawal) {
        require(amount > 0, "amount should greater than 0");
        perpetual.updateCash(trader, amount.neg());
        decreaseTotalCollateral(perpetual, amount);
        int256 markPrice = getMarkPrice(perpetual);
        require(
            perpetual.isInitialMarginSafe(trader, markPrice),
            "margin is unsafe after withdrawal"
        );
        isLastWithdrawal = perpetual.isEmptyAccount(trader);
        if (isLastWithdrawal) {
            deregisterActiveAccount(perpetual, trader);
        }
        emit Withdraw(perpetual.id, trader, amount);
    }

    function clear(PerpetualStorage storage perpetual, address trader)
        public
        returns (bool isAllCleared)
    {
        require(perpetual.activeAccounts.length() > 0, "no account to clear");
        require(
            perpetual.activeAccounts.contains(trader),
            "account cannot be cleared or already cleared"
        );
        countMargin(perpetual, trader);
        perpetual.activeAccounts.remove(trader);
        isAllCleared = (perpetual.activeAccounts.length() == 0);
        emit Clear(perpetual.id, trader);
    }

    function countMargin(PerpetualStorage storage perpetual, address trader) public {
        int256 margin = perpetual.getMargin(trader, getMarkPrice(perpetual));
        if (margin <= 0) {
            return;
        }
        if (perpetual.getPosition(trader) != 0) {
            perpetual.totalMarginWithPosition = perpetual.totalMarginWithPosition.add(margin);
        } else {
            perpetual.totalMarginWithoutPosition = perpetual.totalMarginWithoutPosition.add(margin);
        }
    }

    function getNextActiveAccount(PerpetualStorage storage perpetual)
        public
        view
        returns (address account)
    {
        require(perpetual.activeAccounts.length() > 0, "no active account");
        account = perpetual.activeAccounts.at(0);
    }

    function settle(PerpetualStorage storage perpetual, address trader)
        public
        returns (int256 marginToReturn)
    {
        int256 price = getMarkPrice(perpetual);
        marginToReturn = perpetual.getSettleableMargin(trader, price);
        decreaseTotalCollateral(perpetual, marginToReturn);
        perpetual.resetAccount(trader);
        emit Settle(perpetual.id, trader, marginToReturn);
    }

    function updateInsuranceFund(PerpetualStorage storage perpetual, int256 deltaFund)
        public
        returns (int256 penaltyToLP)
    {
        if (deltaFund == 0) {
            penaltyToLP = 0;
        } else if (perpetual.insuranceFund >= perpetual.insuranceFundCap) {
            penaltyToLP = deltaFund;
        } else {
            int256 newInsuranceFund = perpetual.insuranceFund;
            if (deltaFund > 0) {
                newInsuranceFund = newInsuranceFund.add(deltaFund);
                if (newInsuranceFund > perpetual.insuranceFundCap) {
                    newInsuranceFund = perpetual.insuranceFundCap;
                    penaltyToLP = perpetual.insuranceFundCap.sub(newInsuranceFund);
                }
            } else {
                newInsuranceFund = newInsuranceFund.add(deltaFund);
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

    function settleCollateral(PerpetualStorage storage perpetual) public {
        int256 totalCollateral = perpetual.totalCollateral;
        // 2. cover margin without position
        if (totalCollateral < perpetual.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            perpetual.redemptionRateWithoutPosition = perpetual.totalMarginWithoutPosition > 0
                ? totalCollateral.wdiv(perpetual.totalMarginWithoutPosition)
                : 0;
            // margin with positions will get nothing
            perpetual.redemptionRateWithPosition = 0;
        } else {
            // 3. covere margin with position
            perpetual.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            perpetual.redemptionRateWithPosition = perpetual.totalMarginWithPosition > 0
                ? totalCollateral.sub(perpetual.totalMarginWithoutPosition).wdiv(
                    perpetual.totalMarginWithPosition
                )
                : 0;
        }
    }

    function registerActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.add(trader);
    }

    function deregisterActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.remove(trader);
    }

    // prettier-ignore
    function updatePrice(PerpetualStorage storage perpetual) internal {
        updatePriceData(perpetual.markPriceData, IOracle(perpetual.oracle).priceTWAPLong);
        updatePriceData(perpetual.indexPriceData, IOracle(perpetual.oracle).priceTWAPShort);
    }

    function updatePriceData(
        OraclePriceData storage priceData,
        function() external returns (int256, uint256) priceGetter
    ) internal {
        (int256 price, uint256 time) = priceGetter();
        if (time != priceData.time) {
            priceData.price = price;
            priceData.time = time;
        }
    }

    function increaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        perpetual.totalCollateral = perpetual.totalCollateral.add(amount);
    }

    function decreaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        perpetual.totalCollateral = perpetual.totalCollateral.sub(amount);
        require(perpetual.totalCollateral >= 0, "collateral is negative");
    }

    function updateOption(Option storage option, int256 newValue) internal {
        require(
            newValue >= option.minValue && newValue <= option.maxValue,
            "value is out of range"
        );
        option.value = newValue;
    }

    function setOption(
        Option storage option,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) internal {
        require(newValue >= newMinValue && newValue <= newMaxValue, "value is out of range");
        option.value = newValue;
        option.minValue = newMinValue;
        option.maxValue = newMaxValue;
    }

    function validateBaseParameters(PerpetualStorage storage perpetual) public view {
        require(perpetual.initialMarginRate > 0, "imr should be greater than 0");
        require(perpetual.maintenanceMarginRate > 0, "mmr should be greater than 0");
        require(
            perpetual.maintenanceMarginRate <= perpetual.initialMarginRate,
            "mmr should be lower than imr"
        );
        require(
            perpetual.operatorFeeRate >= 0 &&
                perpetual.operatorFeeRate <= (Constant.SIGNED_ONE / 100),
            "ofr should be within [0, 0.01]"
        );
        require(
            perpetual.lpFeeRate >= 0 && perpetual.lpFeeRate <= (Constant.SIGNED_ONE / 100),
            "lp should be within [0, 0.01]"
        );
        require(
            perpetual.liquidationPenaltyRate >= 0 &&
                perpetual.liquidationPenaltyRate < perpetual.maintenanceMarginRate,
            "lpr should be non-negative and lower than mmr"
        );
        require(perpetual.keeperGasReward >= 0, "kgr should be non-negative");
    }

    function validateRiskParameters(PerpetualStorage storage perpetual) public view {
        require(
            perpetual.halfSpread.value >= 0 && perpetual.halfSpread.value < Constant.SIGNED_ONE,
            "hs shoud be greater than 0 and less than 1"
        );
        require(perpetual.openSlippageFactor.value > 0, "osf shoud be greater than 0");
        require(
            perpetual.closeSlippageFactor.value > 0 &&
                perpetual.closeSlippageFactor.value <= perpetual.openSlippageFactor.value,
            "csf should be within (0, b1]"
        );
        require(perpetual.fundingRateLimit.value >= 0, "frl should be greater than 0");
        require(perpetual.ammMaxLeverage.value > 0, "aml should be greater than 0");
        require(
            perpetual.maxClosePriceDiscount.value >= 0 &&
                perpetual.maxClosePriceDiscount.value < Constant.SIGNED_ONE,
            "mcpd shoud be greater than 0 and less than 1"
        );
    }
}
