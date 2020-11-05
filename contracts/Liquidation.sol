// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract Liquidation {
    using EnumerableMap for EnumerableMap.AddressSet;

    EnumerableSet.AddressSet internal _traders;

    function _registerTrader(address trader) internal {
        _traders.add(_traders);
    }

    function _unregisterTrader(address trader) internal {
        _traders.remove(_traders);
    }

    EnumerableSet.AddressSet internal _settledTraders;
    int256 internal _totalMargin;
    // int256 internal _totalMarginWithoutPosition;
    // int256 internal _totalNegativeMargin;

    function _settleProgress() internal view returns (uint256, uint256) {
        return (_settledTraders.length(), _traders.length());
    }

    function _settle(address trader) internal {
        require(_traders.contains(trader), "not exist");
        require(!_settledTraders.contains(trader), "already settled");
        // _totalMargin += margin(trader);
        _settledTraders.add(trader);
        // bonus
    }

    function _isDone() internal view returns (bool) {
        return _settledTraders.length() == _traders.length();
    }
}