// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./libraries/Bitwise.sol";
import "./libraries/Constant.sol";

import "./Events.sol";

contract AccessControl is Events {
    using Bitwise for uint256;

    uint256 internal constant PRIVILEGE_DEPOSTI = 0x1;
    uint256 internal constant PRIVILEGE_WITHDRAW = 0x2;
    uint256 internal constant PRIVILEGE_TRADE = 0x4;
    uint256 internal constant PRIVILEGE_GUARD = PRIVILEGE_DEPOSTI |
	    PRIVILEGE_WITHDRAW |
	    PRIVILEGE_TRADE;

    mapping(address => mapping(address => uint256)) internal _accessControls;

    modifier auth(address trader, uint256 privilege) {
	    require(
		    trader == msg.sender || isGranted(trader, msg.sender, privilege),
			"operation forbidden"
		);
	    _;
	}

    function grantPrivilege(
	    address owner,
	    address trader,
	    uint256 privilege
	) external {
	    require(_isValid(privilege), "privilege is invalid");
	    _accessControls[owner][trader] = _accessControls[owner][trader].set(privilege);
	    emit GrantPrivilege(owner, trader, privilege);
	}

    function revokePrivilege(
	    address owner,
	    address trader,
	    uint256 privilege
	) external {
	    require(_isValid(privilege), "privilege is invalid");
	    _accessControls[owner][trader] = _accessControls[owner][trader].clean(privilege);
	    emit RevokePrivilege(owner, trader, privilege);
	}

    function isGranted(
	    address owner,
	    address trader,
	    uint256 privilege
	) public view returns (bool) {
	    if (_isValid(privilege)) {
		    return false;
		}
	    return _accessControls[owner][trader] > 0 && _accessControls[owner][trader].test(privilege);
	}

    function _isValid(uint256 privilege) private pure returns (bool) {
	    return privilege > 0 && privilege <= PRIVILEGE_GUARD;
	}

    bytes[50] private __gap;
}
