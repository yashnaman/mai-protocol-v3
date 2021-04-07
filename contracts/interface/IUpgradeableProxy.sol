// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IUpgradeableProxy {
    function implementation() external view returns (address);

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}
