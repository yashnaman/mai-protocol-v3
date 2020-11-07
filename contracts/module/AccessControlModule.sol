// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/Error.sol";
import "../Type.sol";
import "../libraries/Constant.sol";

library AccessControlModule {

    // event GrantPrivilege(address owner, address accessor, uint256 privilege);
    // event RevokePrivilege(address owner, address accessor, uint256 privilege);

    function grantPrivilege(
        AccessControl storage accessControl,
        uint256 privilege
    ) public {
        accessControl.privileges = _setBit(accessControl.privileges, privilege);
    }

    function revokePrivilege(
        AccessControl storage accessControl,
        uint256 privilege
    ) public {
        accessControl.privileges = _cleanBit(accessControl.privileges, privilege);
    }

    function isGranted(
        AccessControl storage accessControl,
        uint256 privilege
    ) internal view returns (bool) {
        return accessControl.privileges > 0 && _testBit(accessControl.privileges, privilege);
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

    function _isValid(uint256 privilege) internal pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }
}