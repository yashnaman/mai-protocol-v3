// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

interface IKeeperWhitelist {
    /**
     * @notice Add an address to keeper whitelist.
     */
    function addKeeper(address keeper) external;

    /**
     * @notice Remove an address from keeper whitelist.
     */
    function removeKeeper(address keeper) external;

    /**
     * @notice Check if an address is in keeper whitelist.
     */
    function isKeeper(address keeper) external view returns (bool);
}
