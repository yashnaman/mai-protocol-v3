// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPool {
    function liquidityPoolInfo()
        external
        view
        returns (
            // [0] factory
            // [1] operator
            // [2] collateral
            // [3] vault
            // [4] governor
            // [5] shareToken
            address[6] memory addresses,
            // [0] vaultFeeRate,
            // [1] insuranceFundCap,
            // [2] insuranceFund,
            // [3] donatedInsuranceFund,
            // [4] totalClaimableFee,
            // [5] poolCashBalance,
            // [6] poolCollateral,
            int256[7] memory nums,
            uint256 perpetualCount,
            uint256 fundingTime
        );

    function perpetualInfo(uint256 perpetualIndex)
        external
        returns (
            PerpetualState state,
            address oracle,
            // [0] depositedCollateral
            // [1] markPrice,
            // [2] indexPrice,
            // [3] unitAccumulativeFunding,
            // [4] initialMarginRate,
            // [5] maintenanceMarginRate,
            // [6] operatorFeeRate,
            // [7] lpFeeRate,
            // [8] referrerRebateRate,
            // [9] liquidationPenaltyRate,
            // [10] keeperGasReward,
            // [11] insuranceFundRate,
            // [12] halfSpread,
            // [13] openSlippageFactor,
            // [14] closeSlippageFactor,
            // [15] fundingRateLimit,
            // [16] maxLeverage
            int256[17] memory nums
        );

    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken
    ) external;

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer,
        bool isCloseOnly
    ) external;

    function brokerTrade(
        Order memory order,
        int256 amount,
        bytes memory signature
    ) external;

    function activeAccountCount(uint256 perpetualIndex) external view returns (uint256);

    function listActiveAccounts(
        uint256 perpetualIndex,
        uint256 start,
        uint256 count
    ) external view returns (address[] memory result);

    function marginAccount(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256 cashBalance, int256 positionAmount);
}
