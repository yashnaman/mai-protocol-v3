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

    function governor() public view returns (address) {
        return _core.governor;
    }

    function shareToken() public view returns (address) {
        return _core.shareToken;
    }

    function sharedLiquidityPoolInfo()
        public
        view
        returns (
            address factory,
            address operator,
            address collateral,
            address vault,
            int256 vaultFeeRate,
            int256 insuranceFund,
            int256 insuranceFundCap,
            int256 donatedInsuranceFund,
            int256 totalClaimableFee,
            int256 poolCashBalance,
            int256 poolCollateral,
            int256 marketCount
        )
    {
        factory = _core.factory;
        operator = _core.operator;
        collateral = _core.collateral;
        vault = _core.vault;
        vaultFeeRate = _core.vaultFeeRate;
        insuranceFund = _core.insuranceFund;
        insuranceFundCap = _core.insuranceFundCap;
        donatedInsuranceFund = _core.donatedInsuranceFund;
        totalClaimableFee = _core.totalClaimableFee;
        poolCashBalance = _core.poolCashBalance;
        poolCollateral = _core.poolCollateral;
        marketCount = _core.markets.length.toInt256();
    }

    function marketInfo(uint256 marketIndex)
        public
        syncState
        onlyExistedMarket(marketIndex)
        returns (
            MarketState state,
            string memory underlyingAsset,
            address collateral,
            address oracle,
            int256 markPrice,
            int256 indexPrice,
            int256 unitAccumulativeFunding,
            int256 fundingRate,
            uint256 fundingTime,
            int256[10] memory coreParameters,
            int256[5] memory riskParameters
        )
    {
        Market storage market = _core.markets[marketIndex];

        state = market.state;
        underlyingAsset = IOracle(market.oracle).underlyingAsset();
        collateral = _core.collateral;
        oracle = market.oracle;
        markPrice = market.markPrice();
        indexPrice = market.indexPrice();
        unitAccumulativeFunding = market.unitAccumulativeFunding;
        fundingRate = market.fundingRate;
        fundingTime = _core.fundingTime;
        coreParameters = [
            market.initialMarginRate,
            market.maintenanceMarginRate,
            market.operatorFeeRate,
            _core.vaultFeeRate,
            market.lpFeeRate,
            market.referrerRebateRate,
            market.liquidationPenaltyRate,
            market.keeperGasReward,
            _core.insuranceFundCap,
            market.insuranceFundRate
        ];
        riskParameters = [
            market.halfSpread.value,
            market.openSlippageFactor.value,
            market.closeSlippageFactor.value,
            market.fundingRateCoefficient.value,
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
