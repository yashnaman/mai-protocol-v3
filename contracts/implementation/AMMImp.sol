// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../Type.sol";
import "../lib/LibConstant.sol";
import "../lib/LibMath.sol";
import "../lib/LibSafeMathExt.sol";

library AMMImp {
    using SignedSafeMath for int256;
    using LibSafeMathExt for int256;
    using LibMath for int256;

    function updateFundingRate(
        Perpetual storage perpetual,
        Context memory context
    ) public {
        // update funding rate.

    }

    function determineDeltaCashBalance(
        Perpetual storage perpetual,
        int256 positionAmount
    ) public returns (int256, int256) {
        MarginAccount memory account = perpetual.traderAccounts[address(this)];
        if (positionAmount > 0) {
            _buy();
        } else {
            _sell();
        }
        return (0, 0);
    }

    function calculateM0(
        Perpetual storage perpetual
    ) public returns (int256) {
        MarginAccount memory account = perpetual.traderAccounts[address(this)];
        if (account.positionAmount == 0) {
            return perpetual.ammSettings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(account.cashBalance);
        } else if (account.positionAmount > 0) {
            int256 b = perpetual.ammSettings.targetLeverage.sub(LibConstant.SIGNED_ONE).wmul(perpetual.state.indexPrice).wmul(account.positionAmount);
            b = b.add(perpetual.ammSettings.targetLeverage.wmul(account.cashBalance));
        }
    }

    function addLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function removeLiquidatity(
        Perpetual storage perpetual,
        int256 amount
    ) public {

    }

    function _buy() internal {

    }

    function _sell() internal {

    }
}
