// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./interface/IFactory.sol";

import "./module/FundingModule.sol";
import "./module/OracleModule.sol";
import "./module/MarginModule.sol";
import "./module/CollateralModule.sol";
import "./module/ParameterModule.sol";
import "./module/SettlementModule.sol";

import "./Type.sol";
import "./Storage.sol";

contract Getter is Storage {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using CollateralModule for address;
    using FundingModule for Core;
    using MarginModule for Core;
    using OracleModule for Market;
    using OracleModule for Core;
    using ParameterModule for Core;
    using SettlementModule for Core;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    function liquidityPoolInfo()
        public
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
            uint256 marketCount,
            uint256 fundingTime
        )
    {
        addresses = [
            _core.factory,
            _core.operator,
            _core.collateral,
            _core.vault,
            _core.governor,
            _core.shareToken
        ];
        nums = [
            _core.vaultFeeRate,
            _core.insuranceFundCap,
            _core.insuranceFund,
            _core.donatedInsuranceFund,
            _core.totalClaimableFee,
            _core.poolCashBalance,
            _core.poolCollateral
        ];
        marketCount = _core.markets.length;
        fundingTime = _core.fundingTime;
    }

    function marketInfo(uint256 marketIndex)
        public
        syncState
        onlyExistedMarket(marketIndex)
        returns (
            MarketState state,
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
        )
    {
        Market storage market = _core.markets[marketIndex];

        state = market.state;
        oracle = market.oracle;
        nums = [
            market.depositedCollateral,
            market.markPrice(),
            market.indexPrice(),
            market.unitAccumulativeFunding,

            market.initialMarginRate,
            market.maintenanceMarginRate,
            market.operatorFeeRate,
            market.lpFeeRate,
            market.referrerRebateRate,
            market.liquidationPenaltyRate,
            market.keeperGasReward,
            market.insuranceFundRate,

            market.halfSpread.value,
            market.openSlippageFactor.value,
            market.closeSlippageFactor.value,
            market.fundingRateLimit.value,
            market.maxLeverage.value
        ];
    }

    function marginAccount(uint256 marketIndex, address trader)
        public
        view
        onlyExistedMarket(marketIndex)
        returns (int256 cashBalance, int256 positionAmount)
    {
        cashBalance = _core.markets[marketIndex].marginAccounts[trader].cashBalance;
        positionAmount = _core.markets[marketIndex].marginAccounts[trader].positionAmount;
    }

    function claimableFee(address claimer) public view returns (int256) {
        return _core.claimableFees[claimer];
    }

    bytes[50] private __gap;
}
