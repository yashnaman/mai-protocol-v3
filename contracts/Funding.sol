// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";
import "./amm/AMMFunding.sol";
import "./Type.sol";
import "./Context.sol";
import "./Margin.sol";
import "./Oracle.sol";

contract Funding is Context, Core, Margin, Oracle {

    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMFunding for FundingState;

    RiskParameter internal _riskParameter;
    FundingState internal _fundingState;

    function _isFundingStateOutdated(uint256 priceTimestamp) internal view returns (bool) {
        return _fundingState.lastFundingTime != _now()
            || _fundingState.lastFundingTime != _indexPriceCache.timestamp
            || _fundingState.lastFundingTime < priceTimestamp;
    }

    function _updateFundingState() internal {
        if (_fundingState.lastFundingTime == 0) {
            return;
        }
        OraclePriceData memory priceData = _indexPriceData();
        if (!_isFundingStateOutdated(priceData.timestamp)) {
            return;
        }
        _fundingState.updateFundingState(
            _riskParameter,
            _marginAccounts[_self()],
            priceData.price,
            priceData.timestamp,
            _now()
        );
    }

    function _updateFundingRate() internal {
        OraclePriceData memory priceData = _indexPriceData();
        _fundingState.updateFundingRate(_riskParameter, _marginAccounts[_self()], priceData.price);
    }

    function _cashBalance(address trader) internal view virtual override returns (int256) {
        int256 fundingLoss = _marginAccounts[trader].entryFundingLoss
            .sub(_marginAccounts[trader].positionAmount.wmul(_fundingState.unitAccFundingLoss));
        return _marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function _closePosition(MarginAccount memory account, int256 amount) internal view override {
        super._closePosition(account, amount);
        int256 partialLoss = account.entryFundingLoss.wfrac(amount, account.positionAmount);
        int256 actualLoss = _fundingState.unitAccFundingLoss
            .wmul(amount)
            .sub(partialLoss);
        account.cashBalance = account.cashBalance.sub(actualLoss);
        account.entryFundingLoss = account.entryFundingLoss.sub(partialLoss);
    }

    function _openPosition(MarginAccount memory account, int256 amount) internal view override {
        super._openPosition(account, amount);
        account.entryFundingLoss = account.entryFundingLoss
                .add(_fundingState.unitAccFundingLoss.wmul(amount));
    }

    function _adjustRiskParameter(bytes32 key, int256 newValue) internal {
        if (key == "halfSpreadRate") {
            _riskParameter.halfSpreadRate.value = newValue;
        } else if (key == "beta1") {
            _riskParameter.beta1.value = newValue;
        } else if (key == "beta2") {
            _riskParameter.beta2.value = newValue;
        } else if (key == "fundingRateCoefficent") {
            _riskParameter.fundingRateCoefficent.value = newValue;
        } else if (key == "virtualLeverage") {
            _riskParameter.virtualLeverage.value = newValue;
        } else {
            revert("key not found");
        }
    }

    function _updateRiskParameter(bytes32 key, int256 newValue, int256 newMinValue, int256 newMaxValue) internal {
        if (key == "halfSpreadRate") {
            _updateOption(_riskParameter.halfSpreadRate, newValue, newMinValue, newMaxValue);
        } else if (key == "beta1") {
            _updateOption(_riskParameter.beta1, newValue, newMinValue, newMaxValue);
        } else if (key == "beta2") {
            _updateOption(_riskParameter.beta2, newValue, newMinValue, newMaxValue);
        } else if (key == "fundingRateCoefficent") {
            _updateOption(_riskParameter.fundingRateCoefficent, newValue, newMinValue, newMaxValue);
        } else if (key == "virtualLeverage") {
            _updateOption(_riskParameter.virtualLeverage, newValue, newMinValue, newMaxValue);
        } else {
            revert("key not found");
        }
    }

    function _updateOption(Option storage option, int256 newValue, int256 newMinValue, int256 newMaxValue) internal {
        option.value = newValue;
        option.minValue = newMinValue;
        option.maxValue = newMaxValue;
    }
}