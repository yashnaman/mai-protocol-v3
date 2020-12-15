// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/FundingModule.sol";

contract TestFunding {

    Core core;
    uint256 currentTime;

    constructor() {
        core.markets.push();
        core.markets.push();
    }

    function setParams(
        int256 unitAccumulativeFunding,
        int256 openSlippageFactor,
        int256 fundingRateCoefficient,
        int256 cashBalance,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice1,
        int256 indexPrice2,
        int256 fundingRate,
        uint256 fundingTime,
        uint256 time
    ) public {
        core.markets[0].id = 0;
        core.markets[0].state = MarketState.NORMAL;
        core.markets[0].unitAccumulativeFunding = unitAccumulativeFunding;
        core.markets[0].openSlippageFactor.value = openSlippageFactor;
        core.markets[0].fundingRateCoefficient.value = fundingRateCoefficient;
        core.markets[0].marginAccounts[address(this)].positionAmount = positionAmount1;
        core.markets[0].indexPriceData.price = indexPrice1;
        core.markets[0].fundingRate = fundingRate;

        core.markets[1].id = 1;
        core.markets[1].state = MarketState.NORMAL;
        core.markets[1].unitAccumulativeFunding = unitAccumulativeFunding;
        core.markets[1].openSlippageFactor.value = openSlippageFactor;
        core.markets[1].fundingRateCoefficient.value = fundingRateCoefficient;
        core.markets[1].marginAccounts[address(this)].positionAmount = positionAmount2;
        core.markets[1].indexPriceData.price = indexPrice2;
        core.markets[1].fundingRate = fundingRate;

        core.poolCashBalance = cashBalance;
        core.fundingTime = fundingTime;
        currentTime = time;
    }

    function updateFundingState() public returns (int256, int256, uint256) {
        FundingModule.updateFundingState(core, currentTime);
        return (core.markets[0].unitAccumulativeFunding, core.markets[1].unitAccumulativeFunding, core.fundingTime);
    }

    function updateFundingRate() public returns (int256, int256) {
        FundingModule.updateFundingRate(core);
        return (core.markets[0].fundingRate, core.markets[1].fundingRate);
    }
}
