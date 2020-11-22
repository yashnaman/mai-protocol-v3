// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";

import "./Type.sol";

contract Fee is Core {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    mapping(address => int256) internal _claimableFee;
    mapping(address => int256) internal _totalFee;

    function _increaseClaimableFee(address claimer, int256 amount) internal {
        if (amount == 0) {
            return;
        }
        _claimableFee[claimer] = _claimableFee[claimer].add(amount);
        _totalFee[claimer] = _totalFee[claimer].add(amount);
    }

    function _claimFee(address claimer, int256 amount) internal {
        require(_claimableFee[claimer].sub(amount) >= 0, "");
        _claimableFee[claimer] = _claimableFee[claimer].sub(amount);
    }
}
