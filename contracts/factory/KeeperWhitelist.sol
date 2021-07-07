// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "../interface/IKeeperWhitelist.sol";

contract KeeperWhitelist is Initializable, OwnableUpgradeable, IKeeperWhitelist {
    mapping(address => bool) internal _keepers;

    event AddKeeperToWhitelist(address indexed keeper);
    event RemoveKeeperFromWhitelist(address indexed keeper);

    /**
     * @notice Add an address to keeper whitelist.
     */
    function addKeeper(address keeper) external virtual override onlyOwner {
        require(keeper != address(0), "account is zero-address");
        require(!isKeeper(keeper), "keeper is already in the whitelist");
        _keepers[keeper] = true;
        emit AddKeeperToWhitelist(keeper);
    }

    /**
     * @notice Remove an address from keeper whitelist.
     */
    function removeKeeper(address keeper) external virtual override onlyOwner {
        require(keeper != address(0), "account is zero-address");
        require(isKeeper(keeper), "keeper is not in the whitelist");
        _keepers[keeper] = false;
        emit RemoveKeeperFromWhitelist(keeper);
    }

    /**
     * @notice Check if an address is in keeper whitelist.
     */
    function isKeeper(address keeper) public view virtual override returns (bool) {
        return _keepers[keeper];
    }
}
