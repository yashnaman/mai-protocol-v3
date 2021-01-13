// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IUpgradeableProxy {
    function implementation() external view returns (address implementation_);

    function upgradeTo(address newImplementation) external;
}

contract TestGovernor is Ownable {
    address[] public history;

    constructor() Ownable() {}

    function initialize(address, address target) external {
        history.push(target);
    }

    function getHistoryLength() public view returns (uint256) {
        return history.length;
    }

    function getImplementation(address liquidityPool)
        external
        view
        onlyOwner
        returns (address implementation)
    {
        implementation = IUpgradeableProxy(liquidityPool).implementation();
    }

    function upgradeTo(address liquidityPool, address newImplementation) external onlyOwner {
        IUpgradeableProxy(liquidityPool).upgradeTo(newImplementation);
    }
}
