// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../lib/LibEnumerableMap.sol";

struct VersionInfo {
    string version;
    address implementation;
    uint256 commitTime;
}

contract PerpetualMaker {
    // implementation list
    mapping(address => VersionInfo) internal _versions;
    VersionInfo[] internal _versionList;

    function addImplementation(bytes32 id, address implementation) external {
    }
    function removeImplementation(bytes32 id) external {
    }
    function verifyImplementation(address implementation) external {
    }

    // create
}