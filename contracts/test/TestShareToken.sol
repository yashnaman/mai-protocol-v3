// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../token/ShareToken.sol";

contract TestShareToken is ShareToken {
    function debugMint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
