// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../thirdparty/upgrades/AdminUpgradeabilityProxy.sol";

/// @title Create a upgradeable proxy as storage of new perpetual.
contract ProxyBuilder {
    event CreateProxy(address location, address implementation, bytes data);

    function _createProxy(
        address implementation,
        address admin,
        bytes memory data
    ) internal returns (address) {
        require(implementation != address(0), "invalid implementation");
        AdminUpgradeabilityProxy newInstance = new AdminUpgradeabilityProxy(
            implementation,
            admin,
            data
        );
        emit CreateProxy(address(newInstance), implementation, data);
        return address(newInstance);
    }

    function _createProxy2(
        address implementation,
        address admin,
        bytes memory data,
        uint256 nonce
    ) internal returns (address instance) {
        require(implementation != address(0), "invalid implementation");
        bytes memory deploymentData = abi.encodePacked(
            type(AdminUpgradeabilityProxy).creationCode,
            abi.encode(implementation, admin, data)
        );
        bytes32 salt = keccak256(abi.encode(implementation, nonce));
        assembly {
            instance := create2(
                0x0,
                add(0x20, deploymentData),
                mload(deploymentData),
                salt
            )
        }
        require(instance != address(0), "Create2 call failed");
    }

    function _deploymentAddress(address implementation, uint256 nonce)
        internal
        returns (address instance)
    {
        require(implementation != address(0), "invalid implementation");
        bytes memory byteCode = type(AdminUpgradeabilityProxy).creationCode;
        bytes32 salt = keccak256(abi.encode(implementation, nonce));
        assembly {
            instance := create2(0x0, add(0x20, byteCode), mload(byteCode), salt)
        }
        require(instance != address(0), "Create2 call failed");
    }
}
