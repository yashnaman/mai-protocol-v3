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
    event GrantPrivilege(address indexed grantor, address indexed grantee, uint256 privilege);
    event RevokePrivilege(address indexed grantor, address indexed grantee, uint256 privilege);

    /**
     * @notice Grant grantee privilege
     * @param grantee The grantee
     * @param privilege The privilege
     */
    function grantPrivilege(address grantee, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(!isGranted(msg.sender, grantee, privilege), "privilege is already granted");
        uint256 grantedPrivileges = _accessControls[msg.sender].contains(grantee)
            ? _accessControls[msg.sender].get(grantee)
            : 0;
        grantedPrivileges = grantedPrivileges.set(privilege);
        _accessControls[msg.sender].set(grantee, grantedPrivileges);
        emit GrantPrivilege(msg.sender, grantee, privilege);
    }

    /**
     * @notice Revoke grantee privilege
     * @param grantee The grantee
     * @param privilege The privilege
     */
    function revokePrivilege(address grantee, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(isGranted(msg.sender, grantee, privilege), "privilege is not granted");
        _accessControls[msg.sender].set(
            grantee,
            _accessControls[msg.sender].get(grantee).clean(privilege)
        );
        emit RevokePrivilege(msg.sender, grantee, privilege);
    }

    /**
     * @notice Check if grantee is granted privilege
     * @param grantor The grantor
     * @param grantee The grantee
     * @param privilege The privilege
     * @return bool If the grantee is granted
     */
    function isGranted(
        address grantor,
        address grantee,
        uint256 privilege
    ) public view returns (bool) {
        if (!_isValid(privilege)) {
            return false;
        }
        if (!_accessControls[grantor].contains(grantee)) {
            return false;
        }
        uint256 granted = _accessControls[grantor].get(grantee);
        return granted > 0 && granted.test(privilege);
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }
}
