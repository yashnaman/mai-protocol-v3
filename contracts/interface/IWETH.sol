// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IWETH {
    function deposit() external payable;

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
