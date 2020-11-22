// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Validator.sol";

library ParameterModule {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
}
