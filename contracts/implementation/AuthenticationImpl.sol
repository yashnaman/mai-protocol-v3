// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Type.sol";
import "../lib/LibError.sol";

library AuthenticationImpl {

    function grantPrivilege(
        Perpetual storage perpetual,
        address owner,
        address accessor,
        bytes32 privilege
    ) internal {
        bytes32 granted = perpetual.accessControls[owner][accessor];
        require(!_testBit(granted, privilege), LibError.PRIVILEGE_ALREADY_SET);
        perpetual.accessControls[owner][accessor] = _setBit(granted, privilege);
    }

    function revokePrivilege(
        Perpetual storage perpetual,
        address owner,
        address accessor,
        bytes32 privilege
    ) internal {
        bytes32 granted = perpetual.accessControls[owner][accessor];
        require(_testBit(granted, privilege), LibError.PRIVILEGE_NOT_SET);
        perpetual.accessControls[owner][accessor] = _cleanBit(granted, privilege);
    }

    function hasPrivilege(
        Perpetual storage perpetual,
        address owner,
        address accessor,
        bytes32 privilege
    ) internal view returns (bool) {
        return _testBit(perpetual.accessControls[owner][accessor], privilege);
    }

    function _testBit(bytes32 value, bytes32 bit) internal pure returns (bool) {
        return value & bit > 0;
    }

    function _setBit(bytes32 value, bytes32 bit) internal pure returns (bytes32) {
        return value | bit;
    }

    function _cleanBit(bytes32 value, bytes32 bit) internal pure returns (bytes32) {
        return value & (~bit);
    }
}