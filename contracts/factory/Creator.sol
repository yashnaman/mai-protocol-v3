// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

/// @title Create a upgradeable proxy as storage of new perpetual.
contract Creator {
    function _createStaticProxy(address implementation) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        UpgradeableProxy newInstance = new UpgradeableProxy(implementation, "");
        return address(newInstance);
    }

    function _createUpgradeableProxy(
        address implementation,
        address admin,
        uint256 nonce
    ) internal returns (address instance) {
        require(implementation != address(0), "invalid implementation");
        require(Address.isContract(implementation), "implementation must be contract");
        bytes memory deploymentData = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(implementation, admin, "")
        );
        bytes32 salt = keccak256(abi.encode(implementation, admin, msg.sender, nonce));
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "create2 call failed");
    }
}
