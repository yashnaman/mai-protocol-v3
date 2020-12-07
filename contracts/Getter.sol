// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

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
    using SafeMath for uint256;
    using CollateralModule for address;
    using FundingModule for Core;
    using MarginModule for Core;
    using OracleModule for Market;
    using OracleModule for Core;
    using ParameterModule for Core;
    using SettlementModule for Core;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function marketDescription(bytes32 marketID)
        public
        view
        returns (
            string memory underlyingAsset,
            address collateral,
            address factory,
            address oracle,
            address operator,
            address vault,
            int256[10] memory coreParameter,
            int256[5] memory riskParameter
        )
    {
        require(_core.marketIDs.contains(marketID), "market not exist");
        factory = _core.factory;
        collateral = _core.collateral;
        operator = _core.operator;
        vault = _core.vault;

        Market storage market = _core.markets[marketID];
        underlyingAsset = IOracle(market.oracle).underlyingAsset();
        oracle = market.oracle;

        coreParameter = [
            market.initialMarginRate,
            market.maintenanceMarginRate,
            market.operatorFeeRate,
            _core.vaultFeeRate,
            market.lpFeeRate,
            market.referrerRebateRate,
            market.liquidationPenaltyRate,
            market.keeperGasReward,
            market.insuranceFundCap,
            market.insuranceFundRate
        ];
        riskParameter = [
            market.spread.value,
            market.openSlippage.value,
            market.closeSlippage.value,
            market.fundingRateCoefficient.value,
            market.maxLeverage.value
        ];
    }

    function marketStatus(bytes32 marketID)
        public
        syncState
        returns (
            bool isEmergency,
            bool isCleared,
            int256 insuranceFund,
            int256 donatedInsuranceFund,
            int256 markPrice,
            int256 indexPrice,
            int256 unitAccumulativeFunding,
            int256 fundingRate,
            uint256 fundingTime
        )
    {
        require(_core.marketIDs.contains(marketID), "market not exist");

        insuranceFund = _core.insuranceFund;
        donatedInsuranceFund = _core.donatedInsuranceFund;

        Market storage market = _core.markets[marketID];
        isEmergency = market.state == MarketState.EMERGENCY;
        isCleared = market.state == MarketState.CLEARED;
        markPrice = market.markPrice();
        indexPrice = market.indexPrice();
        unitAccumulativeFunding = market.unitAccumulativeFunding;
        fundingRate = market.fundingRate;
        fundingTime = market.fundingTime;
    }

    function marginAccount(bytes32 marketID, address trader)
        public
        view
        returns (
            int256 cashBalance,
            int256 positionAmount,
            int256 entryFunding
        )
    {
        require(_core.marketIDs.contains(marketID), "market not exist");
        cashBalance = _core.markets[marketID].marginAccounts[trader].cashBalance;
        positionAmount = _core.markets[marketID].marginAccounts[trader].positionAmount;
        entryFunding = _core.markets[marketID].marginAccounts[trader].entryFunding;
    }

    function claimableFee(address claimer) public view returns (int256) {
        return _core.claimableFees[claimer];
    }

    bytes[50] private __gap;
}
