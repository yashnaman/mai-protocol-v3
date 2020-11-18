// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IFactory {
    function vault() external view returns (address);

    function vaultFeeRate() external view returns (int256);

    function registerUser(address user) external;
}
