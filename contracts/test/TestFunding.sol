// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "../module/FundingModule.sol";

contract TestFunding {
    Core core;
    uint256 currentTime;

    function setParams(
        int256 unitAccumulativeFunding,
        int256 beta1,
        int256 targetLeverage,
        int256 fundingRateCoefficient,
        int256 cashBalance,
        int256 positionAmount,
        int256 entryFunding,
        int256 indexPrice,
        int256 fundingRate,
        uint256 fundingTime,
        uint256 time
    ) public {
        core.unitAccumulativeFunding = unitAccumulativeFunding;
        core.beta1.value = beta1;
        core.targetLeverage.value = targetLeverage;
        core.fundingRateCoefficient.value = fundingRateCoefficient;
        core.marginAccounts[address(this)].cashBalance = cashBalance;
        core.marginAccounts[address(this)].positionAmount = positionAmount;
        core.marginAccounts[address(this)].entryFunding = entryFunding;
        core.indexPriceData.price = indexPrice;
        core.fundingRate = fundingRate;
        core.fundingTime = fundingTime;
        currentTime = time;
    }

    function updateFundingState() public returns (int256, uint256) {
        FundingModule.updateFundingState(core, currentTime);
        return (core.unitAccumulativeFunding, core.fundingTime);
    }

    function nextFundingRate() public returns (int256) {
        return FundingModule.nextFundingRate(core);
    }
}

