// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../thirdparty/proxy/UpgradeableProxy.sol";
import "../thirdparty/cloneFactory/CloneFactory.sol";

import "hardhat/console.sol";

/// @title Create a upgradeable proxy as storage of new liquidityPool.
contract ProxyCreator is CloneFactory {
    function _createClone(address implementation) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        return createClone(implementation);
    }

    function _createUpgradeableProxy(
        address implementation,
        address admin,
        int256 nonce
    ) internal returns (address instance) {
        require(implementation != address(0), "invalid implementation");
        require(Address.isContract(implementation), "implementation must be contract");
        bytes memory deploymentData = abi.encodePacked(
            type(UpgradeableProxy).creationCode,
            abi.encode(implementation, admin)
        );
        bytes32 salt = keccak256(abi.encode(implementation, admin, msg.sender, nonce));
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "create2 call failed");
    }
}
