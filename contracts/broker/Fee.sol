// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Fee {
    mapping(address => uint256) internal _balances;

    function _deposit(uint256 amount) internal {
        // _balances = _balances.add(amount);
    }

    function _withdraw(int256 amount) internal {}
}
