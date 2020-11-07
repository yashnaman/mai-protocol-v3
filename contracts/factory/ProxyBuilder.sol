// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../thirdparty/upgrades/AdminUpgradeabilityProxy.sol";

/// @title Create a upgradeable proxy as storage of new perpetual.
contract ProxyBuilder {

    event CreateProxy(address location, address implementation, bytes data);

    function _createProxy(address implementation, address admin, bytes memory data) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        AdminUpgradeabilityProxy newInstance = new AdminUpgradeabilityProxy(implementation, admin, data);
        emit CreateProxy(address(newInstance), implementation, data);
        return address(newInstance);
    }
}