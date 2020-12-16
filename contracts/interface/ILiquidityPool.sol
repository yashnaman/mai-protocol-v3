// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPool {

    function governor() external view returns (address);

    function shareToken() external view returns (address);

    function liquidityPoolInfo()
        external
        view
        returns (
            address factory,
            address operator,
            address collateral,
            address vault,
            int256 vaultFeeRate,
            int256 insuranceFundCap,
            uint256 marketCount
        );

    function liquidityPoolState()
        external
        view
        returns (
            int256 insuranceFund,
            int256 donatedInsuranceFund,
            int256 totalClaimableFee,
            int256 poolCashBalance,
            int256 poolCollateral,
            uint256 fundingTime
        );

    function marketInfo(uint256 marketIndex)
        external
        returns (
            MarketState state,
            address oracle,
            int256 markPrice,
            int256 indexPrice,
            int256 unitAccumulativeFunding,
            int256 fundingRate,
            int256[8] memory coreParameters,
            int256[5] memory riskParameters
        );

    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken
    ) external;

    function trade(
        uint256 marketIndex,
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

    function activeAccountCount(uint256 marketIndex) external view returns (uint256);

    function listActiveAccounts(
        uint256 marketIndex,
        uint256 start,
        uint256 count
    ) external view returns (address[] memory result);

    function marginAccount(uint256 marketIndex, address trader)
        external
        view
        returns (int256 cashBalance, int256 positionAmount);
}
