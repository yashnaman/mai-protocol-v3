// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/FundingModule.sol";

contract TestFunding {

    Core core;
    uint256 currentTime;

    struct Params {
        int256 unitAccumulativeFunding;
        int256 openSlippageFactor;
        int256 maxLeverage;
        int256 fundingRateLimit;
        int256 cashBalance;
        int256 positionAmount1;
        int256 positionAmount2;
        int256 indexPrice1;
        int256 indexPrice2;
        int256 fundingRate;
        uint256 fundingTime;
        uint256 time;
    }

    constructor() {
        core.markets.push();
        core.markets.push();
    }

    function setParams(
        Params memory params
    ) public {
        core.markets[0].id = 0;
        core.markets[0].state = MarketState.NORMAL;
        core.markets[0].unitAccumulativeFunding = params.unitAccumulativeFunding;
        core.markets[0].openSlippageFactor.value = params.openSlippageFactor;
        core.markets[0].maxLeverage.value = params.maxLeverage;
        core.markets[0].fundingRateLimit.value = params.fundingRateLimit;
        core.markets[0].marginAccounts[address(this)].positionAmount = params.positionAmount1;
        core.markets[0].indexPriceData.price = params.indexPrice1;
        core.markets[0].fundingRate = params.fundingRate;

        core.markets[1].id = 1;
        core.markets[1].state = MarketState.NORMAL;
        core.markets[1].unitAccumulativeFunding = params.unitAccumulativeFunding;
        core.markets[1].openSlippageFactor.value = params.openSlippageFactor;
        core.markets[1].maxLeverage.value = params.maxLeverage;
        core.markets[1].fundingRateLimit.value = params.fundingRateLimit;
        core.markets[1].marginAccounts[address(this)].positionAmount = params.positionAmount2;
        core.markets[1].indexPriceData.price = params.indexPrice2;
        core.markets[1].fundingRate = params.fundingRate;

        core.poolCashBalance = params.cashBalance;
        core.fundingTime = params.fundingTime;
        currentTime = params.time;
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
