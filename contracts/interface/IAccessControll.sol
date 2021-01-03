// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IAccessControll {
    function grantPrivilege(address trader, uint256 privilege) external;

    function revokePrivilege(address trader, uint256 privilege) external;

    function isGranted(
        address owner,
        address trader,
        uint256 privilege
    ) external view returns (bool);
}
