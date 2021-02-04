// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPool {
    /**
     * @notice Get the info of the liquidity pool
     * @return isRunning True if the liquidity pool is running
     * @return isFastCreationEnabled True if the operator of the liquidity pool is allowed to create new perpetual
     *                               when the liquidity pool is running
     * @return addresses The related addresses of the liquidity pool
     * @return vaultFeeRate The vault fee rate of the liquidity pool
     * @return poolCash The pool cash(collateral) of the liquidity pool
     * @return nums Uint type properties, see below for details.
     */
    function getLiquidityPoolInfo()
        external
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
            // [0] collateralDecimals,
            // [1] perpetualCount
            // [2] fundingTime,
            // [3] operatorExpiration,
            uint256[4] memory nums
        );

    /**
     * @notice Get the info of the perpetual. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return state The state of the perpetual
     * @return oracle The oracle's address of the perpetual
     * @return nums The related numbers of the perpetual
     */
    function getPerpetualInfo(uint256 perpetualIndex)
        external
        view
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
        );

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
        external
        view
        returns (
            int256 cash,
            int256 position,
            int256 availableCash,
            int256 margin,
            int256 settleableMargin,
            bool isInitialMarginSafe,
            bool isMaintenanceMarginSafe,
            bool isMarginSafe // bankrupt
        );

    /**
     * @notice Initialize the liquidity pool and set up its configuration
     * @param operator The operator's address of the liquidity pool
     * @param collateral The collateral's address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param governor The governor's address of the liquidity pool
     * @param shareToken The share token's address of the liquidity pool
     * @param isFastCreationEnabled True if the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     */
    function initialize(
        address operator,
        address collateral,
        uint256 collateralDecimals,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) external;

    /**
     * @notice Trade with AMM in the perpetual, require sender is granted the trade privilege by the trader.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of trader
     * @param amount The position amount of the trade
     * @param limitPrice The worst price the trader accepts
     * @param deadline The deadline of the trade
     * @param referrer The referrer's address of the trade
     * @param flags The flags of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        uint32 flags
    ) external returns (int256);

    /**
     * @notice Trade with AMM by the order, initiated by the broker.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param orderData The order data object
     * @param amount The position amount of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function brokerTrade(bytes memory orderData, int256 amount) external returns (int256);

    /**
     * @notice Get the number of active accounts in the perpetual.
     *         Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return activeAccountCount The number of active accounts in the perpetual
     */
    function getActiveAccountCount(uint256 perpetualIndex) external view returns (uint256);

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
    ) external view returns (address[] memory result);

    /**
     * @notice Get the progress of clearing active accounts.
     *         Return the number of total active accounts and the number of active accounts not cleared
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return left The left active accounts
     * @return total The total active accounts
     */
    function getClearProgress(uint256 perpetualIndex)
        external
        view
        returns (uint256 left, uint256 total);

    /**
     * @notice Get the pool margin of the liquidity pool.
     *         Pool margin is how much collateral of the pool considering the AMM's positions of perpetuals
     * @return poolMargin The pool margin of the liquidity pool
     */
    function getPoolMargin() external view returns (int256 poolMargin);

    /**
     * @notice Get the update cash amount and the update position amount of trader
     *         if trader trades with AMM in the perpetual
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param amount The trading amount of position
     * @return deltaCash The update cash(collateral) of the trader after the trade
     * @return deltaPosition The update position of the trader after the trade
     */
    function queryTradeWithAMM(uint256 perpetualIndex, int256 amount)
        external
        view
        returns (int256 deltaCash, int256 deltaPosition);

    /**
     * @notice Get claimable fee of the operator in the liquidity pool
     * @return int256 The claimable fee of the operator in the liquidity pool
     */
    function getClaimableOperatorFee() external view returns (int256);

    /**
     * @notice Get claimable fee of the claimer in the liquidity pool
     * @param claimer The address of the claimer
     * @return int256 The claimable fee of the claimer in the liquidity pool
     */
    function getClaimableFee(address claimer) external view returns (int256);

    function forceToSyncState() external;
}
