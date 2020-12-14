// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../token/ShareToken.sol";

contract TestShareToken is ShareToken {
    function setDefaultAdmin(address admin) public {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }
}
