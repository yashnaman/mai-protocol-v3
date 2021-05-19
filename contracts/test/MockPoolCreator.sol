// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockPoolCreator is Ownable {
    constructor(address owner_) Ownable() {
        transferOwnership(owner_);
    }
}
