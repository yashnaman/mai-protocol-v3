// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./libraries/Bitwise.sol";
import "./libraries/Constant.sol";

import "./Events.sol";
import "./Storage.sol";

import "hardhat/console.sol";

contract AccessControl is Storage, Events {
    using Bitwise for uint256;

    uint256 internal constant PRIVILEGE_DEPOSTI = 0x1;
    uint256 internal constant PRIVILEGE_WITHDRAW = 0x2;
    uint256 internal constant PRIVILEGE_TRADE = 0x4;
    uint256 internal constant PRIVILEGE_GUARD = PRIVILEGE_DEPOSTI |
        PRIVILEGE_WITHDRAW |
        PRIVILEGE_TRADE;

    modifier auth(address trader, uint256 privilege) {
        require(
            trader == msg.sender || isGranted(trader, msg.sender, privilege),
            "operation forbidden"
        );
        _;
    }

    function grantPrivilege(address trader, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(!isGranted(msg.sender, trader, privilege), "privilege is already granted");
        _core.accessControls[msg.sender][trader] = _core.accessControls[msg.sender][trader].set(
            privilege
        );
        emit GrantPrivilege(msg.sender, trader, privilege);
    }

    function revokePrivilege(address trader, uint256 privilege) external {
        require(_isValid(privilege), "privilege is invalid");
        require(isGranted(msg.sender, trader, privilege), "privilege is not granted");
        _core.accessControls[msg.sender][trader] = _core.accessControls[msg.sender][trader].clean(
            privilege
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
        uint256 granted = _core.accessControls[owner][trader];
        return granted > 0 && granted.test(privilege);
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= PRIVILEGE_GUARD;
    }

    bytes[50] private __gap;
}
