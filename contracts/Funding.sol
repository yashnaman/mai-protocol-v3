// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";
import "./libraries/Validator.sol";
import "./amm/AMMFunding.sol";
import "./Type.sol";
import "./Context.sol";
import "./Margin.sol";
import "./Oracle.sol";

contract Funding is Context, Margin {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using AMMFunding for FundingState;
    using Validator for RiskParameter;

    uint256 internal constant RISK_PARAMETER_COUNT = 5;

    RiskParameter internal _riskParameter;
    FundingState internal _fundingState;

    function __FundingInitialize(
        int256[RISK_PARAMETER_COUNT] calldata riskParams,
        int256[RISK_PARAMETER_COUNT] calldata minRiskParamValues,
        int256[RISK_PARAMETER_COUNT] calldata maxRiskParamValues
    ) internal {
        _updateOption(
            _riskParameter.halfSpreadRate,
            riskParams[0],
            minRiskParamValues[0],
            maxRiskParamValues[0]
        );
        _updateOption(
            _riskParameter.beta1,
            riskParams[1],
            minRiskParamValues[1],
            maxRiskParamValues[1]
        );
        _updateOption(
            _riskParameter.beta2,
            riskParams[2],
            minRiskParamValues[2],
            maxRiskParamValues[2]
        );
        _updateOption(
            _riskParameter.fundingRateCoefficient,
            riskParams[3],
            minRiskParamValues[3],
            maxRiskParamValues[3]
        );
        _updateOption(
            _riskParameter.targetLeverage,
            riskParams[4],
            minRiskParamValues[4],
            maxRiskParamValues[4]
        );
        _riskParameter.validate();
    }

    function _isFundingStateOutdated(uint256 priceTimestamp)
        internal
        view
        returns (bool)
    {
        return
            _fundingState.fundingTime != _now() ||
            _fundingState.fundingTime != _indexPriceCache.timestamp ||
            _fundingState.fundingTime < priceTimestamp;
    }

    function _updateFundingState() internal {
        if (_fundingState.fundingTime == 0) {
            return;
        }
        OraclePriceData memory priceData = _indexPriceData();
        if (!_isFundingStateOutdated(priceData.timestamp)) {
            return;
        }
        _fundingState.updateFundingState(_now());
    }

    function _updateFundingRate() internal {
        _fundingState.updateFundingRate(
            _riskParameter,
            _marginAccounts[_self()],
            _indexPrice()
        );
    }

    function _cashBalance(address trader)
        internal
        virtual
        override
        view
        returns (int256)
    {
        int256 fundingLoss = _marginAccounts[trader].entryFundingLoss.sub(
            _marginAccounts[trader].positionAmount.wmul(
                _fundingState.unitAccFundingLoss
            )
        );
        return _marginAccounts[trader].cashBalance.sub(fundingLoss);
    }

    function _closePosition(MarginAccount memory account, int256 amount)
        internal
        override
        view
    {
        super._closePosition(account, amount);
        int256 partialLoss = account.entryFundingLoss.wfrac(
            amount,
            account.positionAmount
        );
        int256 actualLoss = _fundingState.unitAccFundingLoss.wmul(amount).sub(
            partialLoss
        );
        account.cashBalance = account.cashBalance.sub(actualLoss);
        account.entryFundingLoss = account.entryFundingLoss.sub(partialLoss);
    }

    function _openPosition(MarginAccount memory account, int256 amount)
        internal
        override
        view
    {
        super._openPosition(account, amount);
        account.entryFundingLoss = account.entryFundingLoss.add(
            _fundingState.unitAccFundingLoss.wmul(amount)
        );
    }

    function _adjustRiskParameter(bytes32 key, int256 newValue) internal {
        if (key == "halfSpreadRate") {
            _adjustOption(_riskParameter.halfSpreadRate, newValue);
        } else if (key == "beta1") {
            _adjustOption(_riskParameter.beta1, newValue);
        } else if (key == "beta2") {
            _adjustOption(_riskParameter.beta2, newValue);
        } else if (key == "fundingRateCoefficient") {
            _adjustOption(_riskParameter.fundingRateCoefficient, newValue);
        } else if (key == "targetLeverage") {
            _adjustOption(_riskParameter.targetLeverage, newValue);
        } else {
            revert("key not found");
        }
        _riskParameter.validate();
    }

    function _updateRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) internal {
        if (key == "halfSpreadRate") {
            _updateOption(
                _riskParameter.halfSpreadRate,
                newValue,
                newMinValue,
                newMaxValue
            );
        } else if (key == "beta1") {
            _updateOption(
                _riskParameter.beta1,
                newValue,
                newMinValue,
                newMaxValue
            );
        } else if (key == "beta2") {
            _updateOption(
                _riskParameter.beta2,
                newValue,
                newMinValue,
                newMaxValue
            );
        } else if (key == "fundingRateCoefficient") {
            _updateOption(
                _riskParameter.fundingRateCoefficient,
                newValue,
                newMinValue,
                newMaxValue
            );
        } else if (key == "targetLeverage") {
            _updateOption(
                _riskParameter.targetLeverage,
                newValue,
                newMinValue,
                newMaxValue
            );
        } else {
            revert("key not found");
        }
    }

    function _adjustOption(Option storage option, int256 newValue) internal {
        require(newValue >= option.minValue && newValue <= option.maxValue, "");
        option.value = newValue;
    }

    function _updateOption(
        Option storage option,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) internal {
        option.value = newValue;
        option.minValue = newMinValue;
        option.maxValue = newMaxValue;
    }
}
