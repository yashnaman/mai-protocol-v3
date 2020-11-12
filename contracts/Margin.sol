// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";
import "./Context.sol";
import "./Type.sol";
import "./Core.sol";

contract Margin is Core {

    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    mapping(address => MarginAccount) internal _marginAccounts;

    function __MarginInitialize() internal {
    }

    // atribute
    function _initialMargin(address trader, int256 markPrice) internal virtual returns (int256) {
        return _marginAccounts[trader].positionAmount
            .wmul(markPrice)
            .wmul(_initialMarginRate)
            .max(_reservedMargin);
    }

    function _maintenanceMargin(address trader, int256 markPrice) internal virtual returns (int256) {
        return _marginAccounts[trader].positionAmount
            .wmul(markPrice)
            .wmul(_maintenanceMarginRate)
            .max(_reservedMargin);
    }

    function _cashBalance(address trader) internal view virtual returns (int256) {
        return _marginAccounts[trader].cashBalance;
    }

    function _margin(address trader, int256 markPrice) internal virtual returns (int256) {
        return _cashBalance(trader).sub(_marginAccounts[trader].positionAmount.wmul(markPrice));
    }

    function _availableMargin(address trader, int256 markPrice) internal virtual returns (int256) {
        return _margin(trader, markPrice).sub(_initialMargin(trader, markPrice));
    }

    function _isInitialMarginSafe(address trader, int256 markPrice) internal virtual returns (bool) {
        return _margin(trader, markPrice) >= _initialMargin(trader, markPrice);
    }

    function _isMaintenanceMarginSafe(address trader, int256 markPrice) internal virtual returns (bool) {
        return _margin(trader, markPrice) >= _maintenanceMargin(trader, markPrice);
    }

    function _closePosition(MarginAccount memory account, int256 amount) internal view virtual {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.sub(amount);
        require(account.positionAmount.abs() <= previousAmount.abs(), "not closing");
    }

    function _openPosition(MarginAccount memory account, int256 amount) internal view virtual {
        int256 previousAmount = account.positionAmount;
        account.positionAmount = previousAmount.add(amount);
        require(account.positionAmount.abs() >= previousAmount.abs(), "not opening");
    }

    bytes32[50] private __gap;
}