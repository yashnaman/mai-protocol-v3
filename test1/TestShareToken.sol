// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../token/ShareToken.sol";

contract TestShareToken is ShareToken {
    function setAdmin(address admin) public {
        _setupRole(ADMIN_ROLE, admin);
    }
}
