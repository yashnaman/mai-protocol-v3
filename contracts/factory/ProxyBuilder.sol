// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../thirdparty/upgrades/UpgradeabilityProxy.sol";
import "../thirdparty/upgrades/AdminUpgradeabilityProxy.sol";

/// @title Create a upgradeable proxy as storage of new perpetual.
contract ProxyBuilder {
    function _createStaticProxy(address implementation) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        UpgradeabilityProxy newInstance = new UpgradeabilityProxy(implementation, "");
        return address(newInstance);
    }

    function _createPerpetualProxy(
        address implementation,
        address admin,
        uint256 nonce
    ) internal returns (address instance) {
        require(implementation != address(0), "invalid implementation");
        bytes memory deploymentData = abi.encodePacked(
            type(AdminUpgradeabilityProxy).creationCode,
            abi.encode(implementation, admin, "")
        );
        bytes32 salt = keccak256(abi.encode(implementation, admin, msg.sender, nonce));
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "create2 call failed");
    }
}
