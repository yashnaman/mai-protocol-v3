// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";


import "./Type.sol";
import "./Core.sol";
import "./Context.sol";

import "./module/AMMModule.sol";
import "./module/MarginModule.sol";

contract State is Core, Context  {

    using SignedSafeMath for int256;
    using AMMModule for FundingState;
    using MarginModule for MarginAccount;

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

    function _isFundingStateOutOfDate(uint256 newPriceTimestamp) internal view returns (bool) {
        return _fundingState.lastFundingTime != _now()
            || _fundingState.lastFundingTime != _indexOracleData.timestamp
            || _fundingState.lastFundingTime < newPriceTimestamp;
    }


    function _tryUpdateFundingState() internal {
        ( int256 price, uint256 priceTimestamp ) =  _indexPrice();
        if (_isFundingStateOutOfDate(priceTimestamp)) {
            _updateFundingState(price, priceTimestamp);
        }
    }

    function _updateFundingState(int256 indexPrice, uint256 indexPriceTimestamp) internal {
        if (_fundingState.lastFundingTime == 0) {
            return;
        }
        MarginAccount memory ammAccount = _marginAccounts[address(this)];
        int256 unitLoss;
        int256 newFundingRate;
        int256 newUnitAccumulatedFundingLoss = _fundingState.unitAccumulatedFundingLoss;
        // lastFundingTime => price time
        if (indexPriceTimestamp > _fundingState.lastFundingTime) {
            unitLoss = AMMModule.determineDeltaFundingLoss(
                _fundingState.lastIndexPrice,
                _fundingState.fundingRate,
                _fundingState.lastFundingTime,
                indexPriceTimestamp
            );
            newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);
            newFundingRate = AMMModule.calculateBaseFundingRate(
                _settings,
                ammAccount.availableCashBalance(newUnitAccumulatedFundingLoss),
                ammAccount.positionAmount,
                _fundingState.lastIndexPrice
            );
        }
        // price time => now
        unitLoss = AMMModule.determineDeltaFundingLoss(
            indexPrice,
            newFundingRate,
            indexPriceTimestamp,
            _now()
        );
        newUnitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss.add(unitLoss);
        newFundingRate = AMMModule.calculateBaseFundingRate(
            _settings,
            ammAccount.availableCashBalance(newUnitAccumulatedFundingLoss),
            ammAccount.positionAmount,
            indexPrice
        );
        _fundingState.lastIndexPrice = indexPrice;
        _fundingState.lastFundingTime = _now();
        _fundingState.fundingRate = newFundingRate;
        _fundingState.unitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss;
    }
}