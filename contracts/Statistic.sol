// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract Statistic {
    using EnumerableSet for EnumerableSet.GenericEnumerableMap;

    EnumerableMap.GenericEnumerableMap internal _userList;

    function register(address user) internal {
        _userList.set(user);
    }

}