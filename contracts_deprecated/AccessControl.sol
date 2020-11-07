// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./lib/LibError.sol";
import "./Type.sol";

contract AccessControl {

    uint256 constant internal _PRIVILEGE_DEPOSTI = 0x1;
    uint256 constant internal _PRIVILEGE_WITHDRAW = 0x2;
    uint256 constant internal _PRIVILEGE_TRADE = 0x4;
    uint256 constant internal _PRIVILEGE_GUARD = _PRIVILEGE_DEPOSTI | _PRIVILEGE_WITHDRAW | _PRIVILEGE_TRADE;

    mapping(address => mapping(address => uint256)) internal _accessPrivileges;

    event GrantPrivilege(address owner, address accessor, uint256 privilege);
    event RevokePrivilege(address owner, address accessor, uint256 privilege);

    function _grantPrivilege(
        address owner,
        address accessor,
        uint256 privilege
    ) internal {
        require(owner != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(accessor != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(_validatePrivilege(privilege), LibError.INVALID_PRIVILEGE);

        uint256 granted = _accessPrivileges[owner][accessor];
        require(!_testBit(granted, privilege), LibError.PRIVILEGE_ALREADY_SET);
        _accessPrivileges[owner][accessor] = _setBit(granted, privilege);

        emit GrantPrivilege(owner, accessor, privilege);
    }

    function _revokePrivilege(
        address owner,
        address accessor,
        uint256 privilege
    ) internal {
        require(owner != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(accessor != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(_validatePrivilege(privilege), LibError.INVALID_PRIVILEGE);

        uint256 granted = _accessPrivileges[owner][accessor];
        require(_testBit(granted, privilege), LibError.PRIVILEGE_NOT_SET);
        _accessPrivileges[owner][accessor] = _cleanBit(granted, privilege);

        emit RevokePrivilege(owner, accessor, privilege);
    }

    function _hasPrivilege(
        address owner,
        address accessor,
        uint256 privilege
    ) internal view returns (bool) {
        return _testBit(_accessPrivileges[owner][accessor], privilege);
    }

    function _testBit(uint256 value, uint256 bit) internal pure returns (bool) {
        return value & bit > 0;
    }

    function _setBit(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value | bit;
    }

    function _cleanBit(uint256 value, uint256 bit) internal pure returns (uint256) {
        return value & (~bit);
    }

    function _validatePrivilege(uint256 privilege) internal pure returns (bool) {
        return privilege > 0 && privilege <= _PRIVILEGE_GUARD;
    }
}