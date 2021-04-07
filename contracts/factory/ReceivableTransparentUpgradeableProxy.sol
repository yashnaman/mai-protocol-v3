// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract ReceivableTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    receive() external payable override {}

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {}
}
