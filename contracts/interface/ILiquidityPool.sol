// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPool {
    function getLiquidityPoolInfo()
        external
        view
        returns (
            bool isInitialized,
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
        );

    function getPerpetualInfo(uint256 perpetualIndex)
        external
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
        );

    function getMarginAccount(uint256 perpetualIndex, address trader)
        external
        returns (
            int256 cash,
            int256 position,
            int256 availableCash,
            int256 margin,
            int256 settleableMargin,
            bool isInitialMarginSafe,
            bool isMaintenanceMarginSafe,
            bool isBankrupt
        );

    function initialize(
        address operator,
        address collateral,
        uint256 collateralDecimals,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) external;

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    ) external returns (int256);

    function brokerTrade(bytes memory orderData, int256 amount) external returns (int256);

    function activeAccountCount(uint256 perpetualIndex) external view returns (uint256);

    function listActiveAccounts(
        uint256 perpetualIndex,
        uint256 start,
        uint256 count
    ) external view returns (address[] memory result);
}
