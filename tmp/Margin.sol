// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";
import "./Context.sol";
import "./Type.sol";
import "./Type.sol";
import "./State.sol";
import "./Oracle.sol";

contract Margin is Core, State, Oracle {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    OraclePriceData internal _finalMarkPrice;
    mapping(address => MarginAccount) internal _marginAccounts;

    function __MarginInitialize() internal {}

    function _enterEmergencyState() internal virtual override {
        super._enterEmergencyState();
        _finalMarkPrice = super._markPriceData();
    }

    function _markPriceData()
        internal
        virtual
        override
        returns (OraclePriceData memory)
    {
        return _isNormal() ? _markPriceData() : _finalMarkPrice;
    }

    function _indexPriceData()
        internal
        virtual
        override
        returns (OraclePriceData memory)
    {
        return _isNormal() ? _indexPriceData() : _finalMarkPrice;
    }

    // atribute
    function _initialMargin(address trader) internal virtual returns (int256) {
        return
            _marginAccounts[trader]
                .positionAmount
                .wmul(_markPrice())
                .wmul(_coreParameter.initialMarginRate)
                .max(_coreParameter.keeperGasReward);
    }

    function _maintenanceMargin(address trader)
        internal
        virtual
        returns (int256)
    {
        return
            _marginAccounts[trader]
                .positionAmount
                .wmul(_markPrice())
                .wmul(_coreParameter.maintenanceMarginRate)
                .max(_coreParameter.keeperGasReward);
    }

    function _cashBalance(address trader)
        internal
        virtual
        view
        returns (int256)
    {
        return _marginAccounts[trader].cashBalance;
    }

    function _margin(address trader) internal virtual returns (int256) {
        return
            _cashBalance(trader).sub(
                _marginAccounts[trader].positionAmount.wmul(_markPrice())
            );
    }

    function _availableMargin(address trader)
        internal
        virtual
        returns (int256)
    {
        return _margin(trader).sub(_initialMargin(trader));
    }

    function _isInitialMarginSafe(address trader)
        internal
        virtual
        returns (bool)
    {
        return _margin(trader) >= _initialMargin(trader);
    }

    function _isMaintenanceMarginSafe(address trader)
        internal
        virtual
        returns (bool)
    {
        return _margin(trader) >= _maintenanceMargin(trader);
    }

    function _closePosition(MarginAccount memory account, int256 amount)
        internal
        virtual
        view
    {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.sub(amount);
        require(
            account.positionAmount.abs() <= previousAmount.abs(),
            "not closing"
        );
    }

    function _openPosition(MarginAccount memory account, int256 amount)
        internal
        virtual
        view
    {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(
            account.positionAmount.abs() >= previousAmount.abs(),
            "not opening"
        );
    }

    bytes32[50] private __gap;
}
