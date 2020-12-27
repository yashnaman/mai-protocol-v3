// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../libraries/EnumerableMapExt.sol";
import "../libraries/BitwiseMath.sol";
import "../libraries/Constant.sol";

contract AccessControl {
    using BitwiseMath for uint256;
    using EnumerableMapExt for EnumerableMapExt.AddressToUintMap;

    mapping(address => EnumerableMapExt.AddressToUintMap) internal _accessControls;

    // privilege
    event GrantPrivilege(address indexed account, address indexed grantor, uint256 privilege);
    event RevokePrivilege(address indexed account, address indexed grantor, uint256 privilege);

    function grantPrivilege(address grantor, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(!isGranted(msg.sender, grantor, privilege), "privilege is already granted");
        uint256 grantedPrivileges = _accessControls[msg.sender].contains(grantor)
            ? _accessControls[msg.sender].get(grantor)
            : 0;
        grantedPrivileges = grantedPrivileges.set(privilege);
        _accessControls[msg.sender].set(grantor, grantedPrivileges);
        emit GrantPrivilege(msg.sender, grantor, privilege);
    }

    function revokePrivilege(address grantor, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(isGranted(msg.sender, grantor, privilege), "privilege is not granted");
        _accessControls[msg.sender].set(
            grantor,
            _accessControls[msg.sender].get(grantor).clean(privilege)
        );
        emit RevokePrivilege(msg.sender, grantor, privilege);
    }

    function isGranted(
        address account,
        address trader,
        uint256 privilege
    ) public view returns (bool) {
        if (!_isValid(privilege)) {
            return false;
        }
        if (!_accessControls[account].contains(trader)) {
            return false;
        }
        uint256 granted = _accessControls[account].get(trader);
        return granted > 0 && granted.test(privilege);
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }
}
