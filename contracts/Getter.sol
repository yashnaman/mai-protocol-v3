// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./module/MarginAccountModule.sol";
import "./module/PerpetualModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/AMMModule.sol";

import "./Type.sol";
import "./Storage.sol";

contract Getter is Storage {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using CollateralModule for address;
    using Utils for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using AMMModule for LiquidityPoolStorage;

    /**
     * @notice Get the info of the liquidity pool
     * @return isRunning True if the liquidity pool is running
     * @return isFastCreationEnabled True if the operator of the liquidity pool is allowed to create new perpetual
     *                               when the liquidity pool is running
     * @return addresses The related addresses of the liquidity pool
     * @return vaultFeeRate The vault fee rate of the liquidity pool
     * @return poolCash The pool cash(collateral) of the liquidity pool
     * @return collateralDecimals The collateral's decimals of the liquidity pool
     * @return perpetualCount The count of all perpetuals of the liquidity pool
     * @return fundingTime The last update time of funding state
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
            _liquidityPool.getVault()
        ];
        vaultFeeRate = _liquidityPool.getVaultFeeRate();
        poolCash = _liquidityPool.poolCash;
        collateralDecimals = _liquidityPool.collateralDecimals;
        perpetualCount = _liquidityPool.perpetuals.length;
        fundingTime = _liquidityPool.fundingTime;
    }

    /**
     * @notice Get the info of the perpetual. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return state The state of the perpetual
     * @return oracle The oracle's address of the perpetual
     * @return nums The related numbers of the perpetual
     */
    function getPerpetualInfo(uint256 perpetualIndex)
        public
        view
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
            // [9] referralRebateRate,
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
            perpetual.referralRebateRate,
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
     * @notice Get the account info of the trader. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @return cash The cash(collateral) of the account
     * @return position The position of the account
     * @return availableCash The available cash of the account
     * @return margin The margin of the account
     * @return settleableMargin The settleable margin of the account
     * @return isInitialMarginSafe True if the account is initial margin safe
     * @return isMaintenanceMarginSafe True if the account is maintenance margin safe
     * @return isMarginSafe True if the total value of margin account is beyond 0
     */
    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        onlyExistedPerpetual(perpetualIndex)
        returns (
            int256 cash,
            int256 position,
            int256 availableCash,
            int256 margin,
            int256 settleableMargin,
            bool isInitialMarginSafe,
            bool isMaintenanceMarginSafe,
            bool isMarginSafe
        )
    {
        if (trader == address(this)) {
            _liquidityPool.rebalance(perpetualIndex);
        }
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
        isMarginSafe = perpetual.isMarginSafe(trader, markPrice);
    }

    /**
     * @notice Get the number of active accounts in the perpetual.
     *         Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return activeAccountCount The number of active accounts in the perpetual
     */
    function getActiveAccountCount(uint256 perpetualIndex)
        public
        view
        onlyExistedPerpetual(perpetualIndex)
        returns (uint256 activeAccountCount)
    {
        activeAccountCount = _liquidityPool.perpetuals[perpetualIndex].activeAccounts.length();
    }

    /**
     * @notice Get the active accounts in the perpetual whose index between begin and end.
     *         Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param begin The begin index
     * @param end The end index
     * @return result The active accounts in the perpetual whose index between begin and end
     */
    function listActiveAccounts(
        uint256 perpetualIndex,
        uint256 begin,
        uint256 end
    ) public view onlyExistedPerpetual(perpetualIndex) returns (address[] memory result) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        result = perpetual.activeAccounts.toArray(begin, end);
    }

    /**
     * @notice Get the progress of clearing active accounts.
     *         Return the number of total active accounts and the number of active accounts not cleared
     * @param perpetualIndex The index of the perpetual in the liquidity pool
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
     * @notice Get the pool margin of the liquidity pool.
     *         Pool margin is how much collateral of the pool considering the AMM's positions of perpetuals
     * @return poolMargin The pool margin of the liquidity pool
     */
    function getPoolMargin() public view returns (int256 poolMargin) {
        AMMModule.Context memory context = _liquidityPool.prepareContext();
        (poolMargin, ) = AMMModule.getPoolMargin(context);
    }

    /**
     * @notice Get the update cash amount and the update position amount of trader
     *         if trader trades with AMM in the perpetual
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param amount The trading amount of position
     * @return deltaCash The update cash(collateral) of the trader after the trade
     * @return deltaPosition The update position of the trader after the trade
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
     * @notice Get claimable fee of the operator in the liquidity pool
     * @return int256 The claimable fee of the operator in the liquidity pool
     */
    function getClaimableOperatorFee() public view returns (int256) {
        return _liquidityPool.claimableFees[_liquidityPool.operator];
    }

    /**
     * @notice Get claimable fee of the claimer in the liquidity pool
     * @param claimer The address of the claimer
     * @return int256 The claimable fee of the claimer in the liquidity pool
     */
    function getClaimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }

    bytes[50] private __gap;
}
