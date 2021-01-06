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

    function getLiquidityPoolInfo()
        public
        view
        returns (
            // [0] factory,
            // [1] operator,
            // [2] collateral,
            // [3] vault,
            // [4] governor,
            // [5] shareToken,
            address[6] memory addresses,
            // [0] vaultFeeRate,
            // [1] poolCash,
            int256[2] memory nums,
            uint256 collateralDecimals,
            uint256 perpetualCount,
            uint256 fundingTime,
            bool isInitialized,
            bool isFastCreationEnabled
        )
    {
        addresses = [
            _liquidityPool.factory,
            _liquidityPool.operator,
            _liquidityPool.collateralToken,
            _liquidityPool.vault,
            _liquidityPool.governor,
            _liquidityPool.shareToken
        ];
        nums = [_liquidityPool.vaultFeeRate, _liquidityPool.poolCash];
        collateralDecimals = _liquidityPool.collateralDecimals;
        perpetualCount = _liquidityPool.perpetuals.length;
        fundingTime = _liquidityPool.fundingTime;
        isInitialized = _liquidityPool.isInitialized;
        isFastCreationEnabled = _liquidityPool.isFastCreationEnabled;
    }

    function getPerpetualInfo(uint256 perpetualIndex)
        public
        syncState
        onlyExistedPerpetual(perpetualIndex)
        returns (
            PerpetualState state,
            address oracle,
            // [0] totalCollateral
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
            // [12] insuranceFundCap,
            // [13] insuranceFund,
            // [14] donatedInsuranceFund,
            // [15] halfSpread,
            // [16] openSlippageFactor,
            // [17] closeSlippageFactor,
            // [18] fundingRateLimit,
            // [19] ammMaxLeverage
            // [20] maxClosePriceDiscount
            int256[21] memory nums
        )
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        state = perpetual.state;
        oracle = perpetual.oracle;
        nums = [
            perpetual.totalCollateral,
            perpetual.getMarkPrice(),
            perpetual.getIndexPrice(),
            perpetual.unitAccumulativeFunding,
            perpetual.initialMarginRate,
            perpetual.maintenanceMarginRate,
            perpetual.operatorFeeRate,
            perpetual.lpFeeRate,
            perpetual.referrerRebateRate,
            perpetual.liquidationPenaltyRate,
            perpetual.keeperGasReward,
            perpetual.insuranceFundRate,
            perpetual.insuranceFundCap,
            perpetual.insuranceFund,
            perpetual.donatedInsuranceFund,
            perpetual.halfSpread.value,
            perpetual.openSlippageFactor.value,
            perpetual.closeSlippageFactor.value,
            perpetual.fundingRateLimit.value,
            perpetual.ammMaxLeverage.value,
            perpetual.maxClosePriceDiscount.value
        ];
    }

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

    function getPoolMargin() public view returns (int256 poolMargin) {
        AMMModule.Context memory context = _liquidityPool.prepareContext();
        (poolMargin, ) = AMMModule.getPoolMargin(context);
    }

    function getTradePrice(uint256 perpetualIndex, int256 amount)
        public
        view
        returns (int256 deltaCash, int256 deltaPosition)
    {
        (deltaCash, deltaPosition) = _liquidityPool.queryTradeWithAMM(
            perpetualIndex,
            amount.neg(),
            false
        );
    }

    bytes[50] private __gap;
}
