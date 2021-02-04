// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../interface/IOracle.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./MarginAccountModule.sol";

import "../Type.sol";

library PerpetualModule {
    using SafeMathExt for int256;
    using AddressUpgradeable for address;
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using MarginAccountModule for PerpetualStorage;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    event Deposit(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Clear(uint256 perpetualIndex, address indexed trader);
    event Settle(uint256 perpetualIndex, address indexed trader, int256 amount);
    event DonateInsuranceFund(uint256 perpetualIndex, int256 amount);
    event SetNormalState(uint256 perpetualIndex);
    event SetEmergencyState(uint256 perpetualIndex, int256 settlementPrice, uint256 settlementTime);
    event SetClearedState(uint256 perpetualIndex);
    event UpdateUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding);
    event SetPerpetualBaseParameter(uint256 perpetualIndex, int256[9] baseParams);
    event SetPerpetualRiskParameter(
        uint256 perpetualIndex,
        int256[6] riskParams,
        int256[6] minRiskParamValues,
        int256[6] maxRiskParamValues
    );
    event UpdatePerpetualRiskParameter(uint256 perpetualIndex, int256[6] riskParams);
    event TransferExcessInsuranceFundToLP(uint256 perpetualIndex, int256 amount);
    event SetOracle(address indexed oldOralce, address indexed newOracle);

    /**
     * @dev Get the mark price of the perpetual. If the state of the perpetual is not "NORMAL",
     *      return the settlement price
     * @param perpetual The perpetual object
     * @return int256 The mark price of the perpetual
     */
    function getMarkPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.markPriceData.price
                : perpetual.settlementPriceData.price;
    }

    /**
     * @dev Get the index price of the perpetual. If the state of the perpetual is not "NORMAL",
     *      return the settlement price
     * @param perpetual The perpetual object
     * @return int256 The index price of the perpetual
     */
    function getIndexPrice(PerpetualStorage storage perpetual) internal view returns (int256) {
        return
            perpetual.state == PerpetualState.NORMAL
                ? perpetual.indexPriceData.price
                : perpetual.settlementPriceData.price;
    }

    /**
     * @notice Get the margin to rebalance in the perpetual.
     *         Margin to rebalance = margin - initial margin
     * @param perpetual The perpetual object
     * @return marginToRebalance The margin to rebalance in the perpetual
     */
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

    /**
     * @notice Initialize the perpetual. Set up its configuration and validate parameters.
     *         If the validation passed, set the state of perpetual to "INITIALIZING"
     * @param perpetual The perpetual object
     * @param id The id of the perpetual
     * @param oracle The oracle's address of the perpetual
     * @param baseParams The core parameters of the perpetual
     * @param riskParams The risk parameters of the perpetual, must between minimum values and maximum values
     * @param minRiskParamValues The risk parameters' minimum values of the perpetual
     * @param maxRiskParamValues The risk parameters' maximum values of the perpetual
     */
    function initialize(
        PerpetualStorage storage perpetual,
        uint256 id,
        address oracle,
        int256[9] calldata baseParams,
        int256[6] calldata riskParams,
        int256[6] calldata minRiskParamValues,
        int256[6] calldata maxRiskParamValues
    ) public {
        perpetual.id = id;
        perpetual.oracle = oracle;

        setBaseParameter(perpetual, baseParams);
        validateBaseParameters(perpetual);

        setRiskParameter(perpetual, riskParams, minRiskParamValues, maxRiskParamValues);
        validateRiskParameters(perpetual);
        perpetual.state = PerpetualState.INITIALIZING;
    }

    function setOracle(PerpetualStorage storage perpetual, address newOracle) public {
        require(newOracle != address(0), "invalid new oracle address");
        require(newOracle.isContract(), "oracle must be contract");
        require(!IOracle(newOracle).isTerminated(), "oracle is terminated");

        emit SetOracle(perpetual.oracle, newOracle);
        perpetual.oracle = newOracle;
    }

    /**
     * @notice Set the base parameter of the perpetual. Can only called by the governor
     * @param perpetual The perpetual object
     * @param baseParams The new value of the base parameter
     */
    function setBaseParameter(PerpetualStorage storage perpetual, int256[9] memory baseParams)
        public
    {
        perpetual.initialMarginRate = baseParams[0];
        perpetual.maintenanceMarginRate = baseParams[1];
        perpetual.operatorFeeRate = baseParams[2];
        perpetual.lpFeeRate = baseParams[3];
        perpetual.referralRebateRate = baseParams[4];
        perpetual.liquidationPenaltyRate = baseParams[5];
        perpetual.keeperGasReward = baseParams[6];
        perpetual.insuranceFundRate = baseParams[7];
        perpetual.insuranceFundCap = baseParams[8];
        emit SetPerpetualBaseParameter(perpetual.id, baseParams);
    }

    /**
     * @notice Set the risk parameter of the perpetual. Can only called by the governor
     * @param perpetual The perpetual object
     * @param riskParams The new value of the risk parameter, must between minimum value and maximum value
     * @param minRiskParamValues The new minimum value of the risk parameter
     * @param maxRiskParamValues The new maximum value of the risk parameter
     */
    function setRiskParameter(
        PerpetualStorage storage perpetual,
        int256[6] memory riskParams,
        int256[6] memory minRiskParamValues,
        int256[6] memory maxRiskParamValues
    ) public {
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
        emit SetPerpetualRiskParameter(
            perpetual.id,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    /**
     * @notice Update the risk parameter of the perpetual. Can only called by the operator
     * @param perpetual The perpetual object
     * @param riskParams The new value of the risk parameter, must between minimum value and maximum value
     */
    function updateRiskParameter(PerpetualStorage storage perpetual, int256[6] memory riskParams)
        public
    {
        updateOption(perpetual.halfSpread, riskParams[0]);
        updateOption(perpetual.openSlippageFactor, riskParams[1]);
        updateOption(perpetual.closeSlippageFactor, riskParams[2]);
        updateOption(perpetual.fundingRateLimit, riskParams[3]);
        updateOption(perpetual.ammMaxLeverage, riskParams[4]);
        updateOption(perpetual.maxClosePriceDiscount, riskParams[5]);
        emit UpdatePerpetualRiskParameter(perpetual.id, riskParams);
    }

    /**
     * @notice Update the funding state of the perpetual, which means updating the unitAccumulativeFunding variable of the perpetual.
     *         After that, funding payment of every account in the perpetual is updated,
     *         UnitAccumulativeFunding <- unitAccumulativeFunding + index * funding rate * elapsed time / FUNDING_INTERVAL
     * @param perpetual The perpetual object
     * @param timeElapsed The elapsed time since the last update
     */
    function updateFundingState(PerpetualStorage storage perpetual, int256 timeElapsed) public {
        int256 deltaUnitLoss =
            timeElapsed.mul(getIndexPrice(perpetual)).wmul(perpetual.fundingRate).div(
                FUNDING_INTERVAL
            );
        perpetual.unitAccumulativeFunding = perpetual.unitAccumulativeFunding.add(deltaUnitLoss);
        emit UpdateUnitAccumulativeFunding(perpetual.id, perpetual.unitAccumulativeFunding);
    }

    /**
     * @notice Update the funding rate of the perpetual,
     *         funding rate = - index * position * limit / pool margin
     *         funding rate = (+/-)limit if
     *         1. pool margin = 0 and position != 0
     *         2. abs(funding rate) > limit
     * @param perpetual The perpetual object
     * @param poolMargin The pool margin of liquidity pool
     */
    function updateFundingRate(PerpetualStorage storage perpetual, int256 poolMargin) public {
        int256 newFundingRate = 0;
        int256 position = perpetual.getPosition(address(this));
        if (position != 0) {
            int256 fundingRateLimit = perpetual.fundingRateLimit.value;
            if (poolMargin != 0) {
                newFundingRate = getIndexPrice(perpetual).wfrac(position, poolMargin).neg().wmul(
                    fundingRateLimit
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

    /**
     * @notice Set the state of the perpetual to "NORMAL". The state must be "INITIALIZING" before
     * @param perpetual The perpetual object
     */
    function setNormalState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.INITIALIZING,
            "perpetual should be in initializing state"
        );
        perpetual.state = PerpetualState.NORMAL;
        emit SetNormalState(perpetual.id);
    }

    /**
     * @notice Set the state of the perpetual to "EMERGENCY". The state must be "NORMAL" before.
     *         The settlement price is the mark price at this time
     * @param perpetual The perpetual object
     */
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

    // /**
    //  * @notice Set the state of the perpetual to "EMERGENCY". The state must be "NORMAL" before.
    //  *         The settlement price is the mark price at this time
    //  * @param perpetual The perpetual object
    //  */
    // function setEmergencyState(PerpetualStorage storage perpetual, int256 settlementPrice) public {
    //     require(perpetual.state == PerpetualState.NORMAL, "perpetual should be in normal state");
    //     // use mark price as final price when emergency
    //     perpetual.settlementPriceData = OraclePriceData({
    //         price: settlementPrice,
    //         time: block.timestamp
    //     });
    //     perpetual.totalAccount = perpetual.activeAccounts.length();
    //     perpetual.state = PerpetualState.EMERGENCY;
    //     emit SetEmergencyState(
    //         perpetual.id,
    //         perpetual.settlementPriceData.price,
    //         perpetual.settlementPriceData.time
    //     );
    // }

    /**
     * @notice Set the state of the perpetual to "CLEARED". The state must be "EMERGENCY" before.
     *         And settle the collateral of the perpetual, which means
     *         determining how much collateral should returned to every account.
     * @param perpetual The perpetual object
     */
    function setClearedState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.EMERGENCY,
            "perpetual should be in emergency state"
        );
        settleCollateral(perpetual);
        perpetual.state = PerpetualState.CLEARED;
        emit SetClearedState(perpetual.id);
    }

    /**
     * @notice Donate collateral to the insurance fund of the perpetual. All the donated collateral counts towards
     *         the total collateral of perpetual, which means these collateral will be settled when settling the
     *         collateral of the perpetual. Will improve the security of the perpetual.
     * @param perpetual The perpetual object
     * @param amount The amount of collateral to donate
     */
    function donateInsuranceFund(PerpetualStorage storage perpetual, int256 amount) public {
        require(amount > 0, "amount should greater than 0");
        perpetual.donatedInsuranceFund = perpetual.donatedInsuranceFund.add(amount);
        emit DonateInsuranceFund(perpetual.id, amount);
    }

    /**
     * @notice Deposit collateral to the trader's account of the perpetual. The trader's cash will increase.
     *         Activate the perpetual for the trader if the account in the perpetual is empty before depositing.
     *         Empty means cash and position are zero
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param amount The amount of collateral to deposit
     * @return isInitialDeposit True if the trader's account is empty before depositing. If it's true, register
     *                          the trader's account to the active accounts of the perpetual
     */
    function deposit(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isInitialDeposit) {
        require(amount > 0, "amount should greater than 0");
        isInitialDeposit = perpetual.isEmptyAccount(trader);
        perpetual.updateCash(trader, amount);
        if (isInitialDeposit) {
            registerActiveAccount(perpetual, trader);
        }
        emit Deposit(perpetual.id, trader, amount);
    }

    /**
     * @notice Withdraw collateral from the trader's account of the perpetual. The trader's cash will decrease.
     *         Trader must be initial margin safe in the perpetual after withdrawing.
     *         Deactivate the perpetual for the trader if the account in the perpetual is empty after withdrawing.
     *         Empty means cash and position are zero
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param amount The amount of collateral to withdraw
     * @return isLastWithdrawal True if the trader's account is empty after withdrawing. If it's true, deregister
     *                          the trader's account from the active accounts of the perpetual
     */
    function withdraw(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isLastWithdrawal) {
        require(
            perpetual.getPosition(trader) == 0 || !IOracle(perpetual.oracle).isMarketClosed(),
            "market is closed"
        );
        require(amount > 0, "amount should greater than 0");
        perpetual.updateCash(trader, amount.neg());
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

    /**
     * @notice Clear the active account of the perpetual which state is "EMERGENCY" and send gas reward of collateral
     *         to sender. If all active accounts are cleared, the clear progress is done and the perpetual's state will
     *         change to "CLEARED". Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @return isAllCleared If all the active accounts are cleared in the perpetual
     */
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

    /**
     * @notice Check the trader's account to update total margin with position and total margin without position of the perpetual.
     *         If the margin of the trader's account is not positive, skip updating
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     */
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

    /**
     * @notice Get the address of the next active account in the perpetual
     * @param perpetual The perpetual object
     * @return account The address of the next active account
     */
    function getNextActiveAccount(PerpetualStorage storage perpetual)
        public
        view
        returns (address account)
    {
        require(perpetual.activeAccounts.length() > 0, "no active account");
        account = perpetual.activeAccounts.at(0);
    }

    /**
     * @notice If the state of the perpetual is "CLEARED", anyone authorized withdraw privilege by trader can settle
     *         trader's account in the perpetual. Which means to calculate how much the collateral should be returned
     *         to the trader, return it to trader's wallet and clear the trader's cash and position in the perpetual
     * @param perpetual The perpetual object
     * @param trader The adddress of the trader
     * @param marginToReturn The collateral to return to the trader after the settlement
     */
    function settle(PerpetualStorage storage perpetual, address trader)
        public
        returns (int256 marginToReturn)
    {
        int256 price = getMarkPrice(perpetual);
        marginToReturn = perpetual.getSettleableMargin(trader, price);
        perpetual.resetAccount(trader);
        emit Settle(perpetual.id, trader, marginToReturn);
    }

    /**
     * @notice Update the collateral of the insurance fund in the perpetual. If the collateral of the insurance fund
     *         exceeds the cap, the extra part of collateral belongs to LP
     * @param perpetual The perpetual object
     * @param deltaFund The update collateral amount of the insurance fund in the perpetual
     * @return penaltyToLP The extra part of collateral if the collateral of the insurance fund exceeds the cap
     */
    function updateInsuranceFund(PerpetualStorage storage perpetual, int256 deltaFund)
        public
        returns (int256 penaltyToLP)
    {
        penaltyToLP = 0;
        if (deltaFund != 0) {
            int256 newInsuranceFund = perpetual.insuranceFund.add(deltaFund);
            if (deltaFund > 0) {
                if (newInsuranceFund > perpetual.insuranceFundCap) {
                    penaltyToLP = newInsuranceFund.sub(perpetual.insuranceFundCap);
                    newInsuranceFund = perpetual.insuranceFundCap;
                    emit TransferExcessInsuranceFundToLP(perpetual.id, penaltyToLP);
                }
            } else {
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

    /**
     * @notice Settle the total collateral of the perpetual, which means update redemptionRateWithPosition
     *         and redemptionRateWithoutPosition variables. If the total collateral is not enough for the
     *         accounts without position, all the total collateral is given to them proportionally. If the
     *         total collateral is more than the accounts without position needs, the extra part of
     *         collateral is given to the accounts with position proportionally
     * @param perpetual The perpetual object
     */
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

    /**
     * @dev Register the trader's account to the active accounts in the perpetual
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     */
    function registerActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.add(trader);
    }

    /**
     * @dev Deregister the trader's account from the active accounts in the perpetual
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     */
    function deregisterActiveAccount(PerpetualStorage storage perpetual, address trader) internal {
        perpetual.activeAccounts.remove(trader);
    }

    /**
     * @dev Update the oracle price of the perpetual, including the index price and the mark price
     * @param perpetual The perpetual object
     */
    function updatePrice(PerpetualStorage storage perpetual) internal {
        IOracle oracle = IOracle(perpetual.oracle);
        updatePriceData(perpetual.markPriceData, oracle.priceTWAPLong);
        updatePriceData(perpetual.indexPriceData, oracle.priceTWAPShort);
    }

    /**
     * @dev Update the price data, which means the price and the update time
     * @param priceData The price data to update
     * @param priceGetter The function to get the price
     */
    function updatePriceData(
        OraclePriceData storage priceData,
        function() external returns (int256, uint256) priceGetter
    ) internal {
        (int256 price, uint256 time) = priceGetter();
        require(price != 0 && time != 0, "invalid price data");
        if (time >= priceData.time) {
            priceData.price = price;
            priceData.time = time;
        }
    }

    /**
     * @dev Increase the total collateral of the perpetual
     * @param perpetual The perpetual object
     * @param amount The amount of collateral to increase
     */
    function increaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        perpetual.totalCollateral = perpetual.totalCollateral.add(amount);
    }

    /**
     * @dev Decrease the total collateral of the perpetual
     * @param perpetual The perpetual object
     * @param amount The amount of collateral to decrease
     */
    function decreaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        perpetual.totalCollateral = perpetual.totalCollateral.sub(amount);
        require(perpetual.totalCollateral >= 0, "collateral is negative");
    }

    /**
     * @dev Update the option
     * @param option The option to update
     * @param newValue The new value of the option, must between the minimum value and the maximum value
     */
    function updateOption(Option storage option, int256 newValue) internal {
        require(
            newValue >= option.minValue && newValue <= option.maxValue,
            "value is out of range"
        );
        option.value = newValue;
    }

    /**
     * @dev Set the option
     * @param option The option to set
     * @param newValue The new value of the option, must between the minimum value and the maximum value
     * @param newMinValue The minimum value of the option
     * @param newMaxValue The maximum value of the option
     */
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

    /**
     * @notice Validate the base parameters of the perpetual:
     *         1. initial margin rate > 0
     *         2. 0 < maintenance margin rate <= initial margin rate
     *         3. 0 <= operator fee rate <= 0.01
     *         4. 0 <= lp fee rate <= 0.01
     *         5. 0 <= liquidation penalty rate < maintenance margin rate
     *         6. keeper gas reward >= 0
     * @param perpetual The perpetual
     */
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

    /**
     * @notice Validate the risk parameters of the perpetual
     *         1. 0 <= half spread < 1
     *         2. open slippage factor > 0
     *         3. 0 < close slippage factor <= open slippage factor
     *         4. funding rate limit >= 0
     *         5. AMM max leverage > 0
     *         6. 0 <= max close price discount < 1
     * @param perpetual The perpetual
     */
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
