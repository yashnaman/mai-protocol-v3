// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";
import "./amm/AMMFunding.sol";
import "./Type.sol";
import "./CallContext.sol";
import "./Margin.sol";
import "./Oracle.sol";

contract Funding is CallContext, Core, Margin, Oracle {

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
        account.entryFundingLoss = account.entryFundingLoss
                .wfrac(account.positionAmount.sub(amount), account.positionAmount);
    }

    function _openPosition(MarginAccount memory account, int256 amount) internal view override {
        super._openPosition(account, amount);
        account.entryFundingLoss = account.entryFundingLoss
                .add(_fundingState.unitAccFundingLoss.wmul(amount));
    }
}