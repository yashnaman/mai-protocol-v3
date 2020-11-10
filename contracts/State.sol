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

    function _markPrice() internal view returns (int256 price) {
        return _markPriceData().price;
    }

    function _markPriceData() internal view returns (OraclePrice memory) {
        if (_now() == _marketOracleData.timestamp) {
            return _marketOracleData;
        }
        return OraclePrice(0, 0);
    }

    function _indexPrice() internal view returns (int256 price) {
        return _indexPriceData().price;
    }

    function _indexPriceData() internal view returns (OraclePrice memory) {
        if (_now() == _indexOracleData.timestamp) {
            return _indexOracleData;
        }
        return OraclePrice(0, 0);
    }

    function _isFundingStateOutdated(uint256 newPriceTimestamp) internal view returns (bool) {
        return _fundingState.lastFundingTime != _now()
            || _fundingState.lastFundingTime != _indexOracleData.timestamp
            || _fundingState.lastFundingTime < newPriceTimestamp;
    }

    function _updatePreFundingState() internal {
        if (_fundingState.lastFundingTime == 0) {
            return;
        }
        OraclePrice memory priceData = _indexPriceData();
        if (!_isFundingStateOutdated(priceData.timestamp)) {
            return;
        }
        uint256 endFundingTime = _now();
        (
            int256 newUnitAccumulatedFundingLoss,
            int256 newFundingRate
        ) = _fundingState.calculateNextFundingState(
            _settings,
            _marginAccounts[_self()],
            priceData,
            endFundingTime
        );
        _fundingState.lastIndexPrice = priceData.price;
        _fundingState.lastFundingTime = endFundingTime;
        _fundingState.fundingRate = newFundingRate;
        _fundingState.unitAccumulatedFundingLoss = newUnitAccumulatedFundingLoss;
    }

    function _updatePostFundingState() internal {
        OraclePrice memory priceData = _indexPriceData();
        int256 newFundingRate = _fundingState.calculateNextFundingRate(
            _settings,
            _marginAccounts[_self()],
            priceData.price
        );
        _fundingState.fundingRate = newFundingRate;
    }
}