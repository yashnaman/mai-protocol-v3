// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/FundingModule.sol";

contract TestFunding {

    LiquidityPoolStorage liquidityPool;
    uint256 currentTime;

    struct Params {
        PerpetualState state;
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
        liquidityPool.perpetuals.push();
        liquidityPool.perpetuals.push();
    }

    function setParams(
        Params memory params
    ) public {
        liquidityPool.perpetuals[0].id = 0;
        liquidityPool.perpetuals[0].state = PerpetualState.NORMAL;
        liquidityPool.perpetuals[0].unitAccumulativeFunding = params.unitAccumulativeFunding;
        liquidityPool.perpetuals[0].openSlippageFactor.value = params.openSlippageFactor;
        liquidityPool.perpetuals[0].maxLeverage.value = params.maxLeverage;
        liquidityPool.perpetuals[0].fundingRateLimit.value = params.fundingRateLimit;
        liquidityPool.perpetuals[0].marginAccounts[address(this)].positionAmount = params.positionAmount1;
        liquidityPool.perpetuals[0].indexPriceData.price = params.indexPrice1;
        liquidityPool.perpetuals[0].fundingRate = params.fundingRate;

        liquidityPool.perpetuals[1].id = 1;
        liquidityPool.perpetuals[1].state = PerpetualState.NORMAL;
        liquidityPool.perpetuals[1].unitAccumulativeFunding = params.unitAccumulativeFunding;
        liquidityPool.perpetuals[1].openSlippageFactor.value = params.openSlippageFactor;
        liquidityPool.perpetuals[1].maxLeverage.value = params.maxLeverage;
        liquidityPool.perpetuals[1].fundingRateLimit.value = params.fundingRateLimit;
        liquidityPool.perpetuals[1].marginAccounts[address(this)].positionAmount = params.positionAmount2;
        liquidityPool.perpetuals[1].indexPriceData.price = params.indexPrice2;
        liquidityPool.perpetuals[1].fundingRate = params.fundingRate;

        liquidityPool.poolCashBalance = params.cashBalance;
        liquidityPool.fundingTime = params.fundingTime;
        currentTime = params.time;
    }

    function updateFundingState() public returns (int256, int256, uint256) {
        FundingModule.updateFundingState(liquidityPool, currentTime);
        return (liquidityPool.perpetuals[0].unitAccumulativeFunding, liquidityPool.perpetuals[1].unitAccumulativeFunding, liquidityPool.fundingTime);
    }

    function updateFundingRate() public returns (int256, int256) {
        FundingModule.updateFundingRate(liquidityPool);
        return (liquidityPool.perpetuals[0].fundingRate, liquidityPool.perpetuals[1].fundingRate);
    }
}
