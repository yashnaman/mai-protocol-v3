// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./libraries/SafeMathExt.sol";
import "./Funding.sol";

contract Settle is Funding {
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using EnumerableSet for EnumerableSet.AddressSet;

    int256 internal _clearingPayout;
    int256 internal _marginWithPosition;
    int256 internal _marginWithoutPosition;

    int256 internal _withdrawableMarginWithPosition;
    int256 internal _withdrawableMarginWithoutPosition;

    EnumerableSet.AddressSet internal _registeredUsers;
    EnumerableSet.AddressSet internal _clearedUsers;

    function _registerUser(address user) internal {
        _registeredUsers.add(user);
    }

    function _deregisterUser(address user) internal {
        _registeredUsers.remove(user);
    }

    function _numUserToClear() internal view returns (uint256) {
        return _registeredUsers.length();
    }

    function _listUserToClear(uint256 begin, uint256 end)
        internal
        view
        returns (address[] memory)
    {
        require(end <= _registeredUsers.length(), "exceeded");
        address[] memory result = new address[](end.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _registeredUsers.at(i);
        }
        return result;
    }

    function _isCleared() internal view returns (bool) {
        return _registeredUsers.length() == 0;
    }

    function _clear(address user) internal {
        int256 margin = _margin(user);
        if (_marginAccounts[user].positionAmount != 0) {
            _marginWithPosition = _marginWithPosition.add(margin);
        } else {
            _marginWithoutPosition = _marginWithoutPosition.add(margin);
        }
        bool removed = _registeredUsers.remove(user);
        require(removed, "already cleared");
        _clearedUsers.add(user);

        if (_isCleared()) {
            _setWithdrawableMargin();
        }

        // _clearingPayout = _clearingPayout.add()
    }

    function _setWithdrawableMargin() internal {
        // _collteral.balanceOf(aaa);
        int256 totalBalance;
        if (totalBalance < _marginWithoutPosition) {
            _withdrawableMarginWithoutPosition = totalBalance;
            totalBalance = 0;
        } else {
            _withdrawableMarginWithoutPosition = _marginWithoutPosition;
            totalBalance = totalBalance.sub(_marginWithoutPosition);
        }
        if (totalBalance > 0) {
            _withdrawableMarginWithPosition = totalBalance;
        } else {
            _withdrawableMarginWithPosition = 0;
        }
    }

    function _settle(address user) internal returns (int256 amount) {
        int256 margin = _margin(user);
        if (_marginAccounts[user].positionAmount != 0) {
            amount = _withdrawableMarginWithPosition.wfrac(
                margin,
                _marginWithPosition
            );
            _marginWithPosition = _marginWithPosition.sub(margin);
            _withdrawableMarginWithPosition = _withdrawableMarginWithPosition
                .sub(amount);
        } else {
            amount = _withdrawableMarginWithoutPosition.wfrac(
                margin,
                _marginWithoutPosition
            );
            _marginWithoutPosition = _marginWithoutPosition.sub(margin);
            _withdrawableMarginWithoutPosition = _withdrawableMarginWithoutPosition
                .sub(amount);
        }
    }

    bytes32[50] private __gap;
}
