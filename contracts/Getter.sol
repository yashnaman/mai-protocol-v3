// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./libraries/SafeMathExt.sol";

import "./module/MarginAccountModule.sol";
import "./module/PerpetualModule.sol";
import "./module/AMMModule.sol";

import "./Type.sol";
import "./Storage.sol";

contract Getter is Storage {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using CollateralModule for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using AMMModule for LiquidityPoolStorage;

    /**
     * @notice Get liquidity pool info
     * @return isRunning If liquidity pool is running
     * @return isFastCreationEnabled If operator is allowed to create perpetual
     * @return addresses The related addresses of liquidity pool
     * @return vaultFeeRate The vault fee rate of liquidity pool
     * @return poolCash The pool cash of liquidity pool
     * @return collateralDecimals The decimal of collateral
     * @return perpetualCount The count of all perpetuals
     * @return fundingTime The last time updated funding state
     */
    function getLiquidityPoolInfo()
        public
        view
        returns (
            bool isRunning,
            bool isFastCreationEnabled,
            // [0] creator,
            // [1] operator,
            // [2] transferringOperator,
            // [3] governor,
            // [4] shareToken,
            // [5] collateralToken,
            // [6] vault,
            address[7] memory addresses,
            int256 vaultFeeRate,
            int256 poolCash,
            uint256 collateralDecimals,
            uint256 perpetualCount,
            uint256 fundingTime
        )
    {
        isRunning = _liquidityPool.isRunning;
        isFastCreationEnabled = _liquidityPool.isFastCreationEnabled;
        addresses = [
            _liquidityPool.creator,
            _liquidityPool.operator,
            _liquidityPool.transferringOperator,
            _liquidityPool.governor,
            _liquidityPool.shareToken,
            _liquidityPool.collateralToken,
            _liquidityPool.vault
        ];
        vaultFeeRate = _liquidityPool.vaultFeeRate;
        poolCash = _liquidityPool.poolCash;
        collateralDecimals = _liquidityPool.collateralDecimals;
        perpetualCount = _liquidityPool.perpetuals.length;
        fundingTime = _liquidityPool.fundingTime;
    }

    /**
     * @notice Get perpetual info
     * @param perpetualIndex The index of perpetual
     * @return state The state of perpetual
     * @return oracle The oracle of perpetual
     * @return nums The related numbers of perpetual
     */
    function getPerpetualInfo(uint256 perpetualIndex)
        public
        syncState
        onlyExistedPerpetual(perpetualIndex)
        returns (
            PerpetualState state,
            address oracle,
            // [0] totalCollateral
            // [1] markPrice, (return settlementPrice if it is in EMERGENCY state)
            // [2] indexPrice,
            // [3] fundingRate,
            // [4] unitAccumulativeFunding,
            // [5] initialMarginRate,
            // [6] maintenanceMarginRate,
            // [7] operatorFeeRate,
            // [8] lpFeeRate,
            // [9] referrerRebateRate,
            // [10] liquidationPenaltyRate,
            // [11] keeperGasReward,
            // [12] insuranceFundRate,
            // [13] insuranceFundCap,
            // [14] insuranceFund,
            // [15] donatedInsuranceFund,
            // [16-18] halfSpread value, min, max,
            // [19-21] openSlippageFactor value, min, max,
            // [22-24] closeSlippageFactor value, min, max,
            // [25-27] fundingRateLimit value, min, max,
            // [28-30] ammMaxLeverage value, min, max,
            // [31-33] maxClosePriceDiscount value, min, max,
            int256[34] memory nums
        )
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        state = perpetual.state;
        oracle = perpetual.oracle;
        nums = [
            // [0]
            perpetual.totalCollateral,
            perpetual.getMarkPrice(),
            perpetual.getIndexPrice(),
            perpetual.fundingRate,
            perpetual.unitAccumulativeFunding,
            perpetual.initialMarginRate,
            perpetual.maintenanceMarginRate,
            perpetual.operatorFeeRate,
            perpetual.lpFeeRate,
            perpetual.referrerRebateRate,
            // [10]
            perpetual.liquidationPenaltyRate,
            perpetual.keeperGasReward,
            perpetual.insuranceFundRate,
            perpetual.insuranceFundCap,
            perpetual.insuranceFund,
            perpetual.donatedInsuranceFund,
            perpetual.halfSpread.value,
            perpetual.halfSpread.minValue,
            perpetual.halfSpread.maxValue,
            perpetual.openSlippageFactor.value,
            // [20]
            perpetual.openSlippageFactor.minValue,
            perpetual.openSlippageFactor.maxValue,
            perpetual.closeSlippageFactor.value,
            perpetual.closeSlippageFactor.minValue,
            perpetual.closeSlippageFactor.maxValue,
            perpetual.fundingRateLimit.value,
            perpetual.fundingRateLimit.minValue,
            perpetual.fundingRateLimit.maxValue,
            perpetual.ammMaxLeverage.value,
            perpetual.ammMaxLeverage.minValue,
            // [30]
            perpetual.ammMaxLeverage.maxValue,
            perpetual.maxClosePriceDiscount.value,
            perpetual.maxClosePriceDiscount.minValue,
            perpetual.maxClosePriceDiscount.maxValue
        ];
    }

    /**
     * @notice Get account info of trader
     * @param perpetualIndex The index of perpetual
     * @param trader The trader
     * @return cash The cash of the account
     * @return position The position of the account
     * @return availableCash The available cash of the account
     * @return margin The margin of the account
     * @return settleableMargin The settleable margin of the account
     * @return isInitialMarginSafe If the account is initial margin safe
     * @return isMaintenanceMarginSafe If the account is maintenance margin safe
     * @return isBankrupt If the account is bankrupt
     */
    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        syncState
        onlyExistedPerpetual(perpetualIndex)
        returns (
            int256 cash,
            int256 position,
            int256 availableCash,
            int256 margin,
            int256 settleableMargin,
            bool isInitialMarginSafe,
            bool isMaintenanceMarginSafe,
            bool isBankrupt
        )
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        MarginAccount storage account = perpetual.marginAccounts[trader];
        int256 markPrice = perpetual.getMarkPrice();
        cash = account.cash;
        position = account.position;
        availableCash = perpetual.getAvailableCash(trader);
        margin = perpetual.getMargin(trader, markPrice);
        settleableMargin = perpetual.getSettleableMargin(trader, markPrice);
        isInitialMarginSafe = perpetual.isInitialMarginSafe(trader, markPrice);
        isMaintenanceMarginSafe = perpetual.isMaintenanceMarginSafe(trader, markPrice);
        isBankrupt = !perpetual.isMarginSafe(trader, markPrice);
    }

    /**
     * @notice Get progress of clearing active accounts
     * @param perpetualIndex The index of perpetual
     * @return left The left active accounts
     * @return total The total active accounts
     */
    function getClearProgress(uint256 perpetualIndex)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (uint256 left, uint256 total)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        left = perpetual.activeAccounts.length();
        total = perpetual.state == PerpetualState.NORMAL
            ? perpetual.activeAccounts.length()
            : perpetual.totalAccount;
    }

    /**
     * @notice Get pool margin of liquidity pool
     * @return poolMargin The pool margin of liquidity pool
     */
    function getPoolMargin() public view returns (int256 poolMargin) {
        AMMModule.Context memory context = _liquidityPool.prepareContext();
        (poolMargin, ) = AMMModule.getPoolMargin(context);
    }

    /**
     * @notice Get query result of trading with amm, excluding fee
     * @param perpetualIndex The index of perpetual
     * @param amount The trading amount
     * @return deltaCash The delta cash of trader
     * @return deltaPosition The delta position of trader
     */
    function queryTradeWithAMM(uint256 perpetualIndex, int256 amount)
        public
        view
        returns (int256 deltaCash, int256 deltaPosition)
    {
        (deltaCash, deltaPosition) = _liquidityPool.queryTradeWithAMM(
            perpetualIndex,
            amount.neg(),
            false
        );
        deltaCash = deltaCash.neg();
        deltaPosition = deltaPosition.neg();
    }

    /**
     * @notice Get claimable fee of operator
     * @return int256 The claimable fee of the operator
     */
    function getClaimableOperatorFee() public view returns (int256) {
        return _liquidityPool.claimableFees[_liquidityPool.operator];
    }

    /**
     * @notice Get claimable fee of claimer
     * @param claimer The claimer
     * @return int256 The claimable fee of the claimer
     */
    function getClaimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }

    bytes[50] private __gap;
}
