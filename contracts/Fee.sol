// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "./libraries/SafeMathExt.sol";

import "./Core.sol";

contract Fee is Core {
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    int256 internal _claimableVaultFee;
    int256 internal _totalVaultFee;

    int256 internal _claimableOperatorFee;
    int256 internal _totalOperatorFee;

    function _updateTradingFee(int256 margin) internal returns (int256) {
        int256 vaultFee = margin.wmul(_vaultFeeRate());
        int256 operatorFee = margin.wmul(_operatorFeeRate);
        _claimableVaultFee = _claimableVaultFee.add(vaultFee);
        _claimableOperatorFee = _claimableOperatorFee.add(operatorFee);
        return vaultFee.add(operatorFee);
    }

}