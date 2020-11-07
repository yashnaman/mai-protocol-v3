// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./Type.sol";
import "./Core.sol";
import "./Context.sol";

import "./module/AMMModule.sol";

contract State is Core, Context  {

    using AMMModule for FundingState;

    function _markPrice() internal returns (int256 price, uint256 updateTimestamp) {
        if (_now() == _marketOracleData.timestamp) {
            return (_marketOracleData.price, _marketOracleData.timestamp);
        }
        return (0, 0);
    }

    function _indexPrice() internal returns (int256 price, uint256 updateTimestamp) {
        if (_now() == _indexOracleData.timestamp) {
            return (_indexOracleData.price, _indexOracleData.timestamp);
        }
        return (0, 0);
    }

    function _isFundingStateOutOfDate(int256 newPrice, uint256 newPriceTimestamp) internal view returns (bool) {
        return _fundingState.lastFundingTime != _now()
            || _fundingState.lastFundingTime != _indexOracleData.timestamp
            || _fundingState.lastFundingTime < newPriceTimestamp;
    }


    function _tryUpdateFundingState() internal {
        ( int256 newPrice, uint256 newPriceTimestamp ) =  _indexPrice();
        if (_isFundingStateOutOfDate(newPrice, newPriceTimestamp)) {
            _updateFundingState();
        }
    }

    function _updateFundingState(int256 price, uint256 priceTimestamp) internal {
        if (_fundingState.lastFundingTime == 0) {
            return;
        }
        MarginAccount memory ammAccount = _marginAccounts[address(this)];
        int256 newFundingRate = 0;
        int256 newUnitAccumulatedFundingLoss = _fundingState.unitAccumulatedFundingLoss;
        // lastFundingTime => price time
        if (newPriceTimestamp > _fundingState.lastFundingTime) {
            int256 unitLoss = _fundingState.determineDeltaFundingLoss(
                _fundingState.lastIndexPrice,
                _fundingState.fundingRate,
                _fundingState.lastFundingTime,
                priceTimestamp
            );
            newFundingRate = _fundingState.calculateBaseFundingRate(
                _settings,
                ammAccount.availableCashBalance(),
                ammAccount.positionAmount,
                price
            );
            newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);
        }
        // price time => now
        int256 unitLoss = _fundingState.determineDeltaFundingLoss(
            price,
            newFundingRate,
            priceTimestamp,
            _now()
        );
        newFundingRate = _fundingState.calculateBaseFundingRate(
            _settings,
            ammAccount.availableCashBalance(),
            ammAccount.positionAmount,
            price
        );
        newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);

        _fundingState.lastIndexPrice = price;
        _fundingState.lastFundingTime = _now();
        _fundingState.fundingRate = newFundingRate;
        _fundingState.unitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss;
    }
}