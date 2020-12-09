// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../libraries/EnumerableMapExt.sol";
import "../libraries/Bitwise.sol";
import "../libraries/Constant.sol";

contract AccessControl {
    using Bitwise for uint256;
    using EnumerableMapExt for EnumerableMapExt.AddressToUintMap;

    mapping(address => EnumerableMapExt.AddressToUintMap) _accessControls;

    // privilege
    event GrantPrivilege(address indexed owner, address indexed trader, uint256 privilege);
    event RevokePrivilege(address indexed owner, address indexed trader, uint256 privilege);

    function grantPrivilege(address trader, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(!isGranted(msg.sender, trader, privilege), "privilege is already granted");
        _accessControls[msg.sender].set(
            trader,
            _accessControls[msg.sender].get(trader).set(privilege)
        );
        emit GrantPrivilege(msg.sender, trader, privilege);
    }

    function revokePrivilege(address trader, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(isGranted(msg.sender, trader, privilege), "privilege is not granted");
        _accessControls[msg.sender].set(
            trader,
            _accessControls[msg.sender].get(trader).clean(privilege)
        );
        emit RevokePrivilege(msg.sender, trader, privilege);
    }

    function isGranted(
        address owner,
        address trader,
        uint256 privilege
    ) public view returns (bool) {
        if (!_isValid(privilege)) {
            return false;
        }
        uint256 granted = _accessControls[owner].get(trader);
        return granted > 0 && granted.test(privilege);
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }
}
