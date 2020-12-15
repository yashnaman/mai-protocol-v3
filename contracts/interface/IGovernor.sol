// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IGovernor {
    function initialize(address _voteToken, address _target) external;
}
