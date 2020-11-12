// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./libraries/Bitwise.sol";
import "./libraries/Constant.sol";

contract AccessControl {

    using Bitwise for uint256;

    mapping(address => mapping(address => uint256)) internal _accessControls;

    event GrantPrivilege(address owner, address accessor, uint256 privilege);
    event RevokePrivilege(address owner, address accessor, uint256 privilege);

    function _grantPrivilege(address owner, address trader, uint256 privilege) internal {
        _accessControls[owner][trader] = _accessControls[owner][trader].set(privilege);
    }

    function revokePrivilege(address owner, address trader, uint256 privilege) internal {
        _accessControls[owner][trader] = _accessControls[owner][trader].clean(privilege);
    }

    function isGranted(address owner, address trader, uint256 privilege) internal view returns (bool) {
        return  _accessControls[owner][trader] > 0 && _accessControls[owner][trader].test(privilege);
    }

    function _isValid(uint256 privilege) internal pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }

}