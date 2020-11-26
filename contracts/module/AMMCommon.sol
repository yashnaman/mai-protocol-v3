// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../Type.sol";

library AMMCommon {
    using Math for int256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;

    function regress(
        int256 mc,
        int256 positionAmount,
        int256 indexPrice,
        int256 targetLeverage,
        int256 beta
    ) internal pure returns (int256 mv, int256 m0) {
        if (positionAmount == 0) {
            mv = targetLeverage.sub(Constant.SIGNED_ONE).wmul(mc);
        } else if (positionAmount > 0) {
            mv = _longVirtualMargin(mc, positionAmount, indexPrice, targetLeverage, beta);
        } else {
            mv = _shortVirtualMargin(mc, positionAmount, indexPrice, targetLeverage, beta);
        }
        m0 = mv.wfrac(targetLeverage, targetLeverage.sub(Constant.SIGNED_ONE));
    }

    function _longVirtualMargin(
        int256 mc,
        int256 positionAmount,
        int256 indexPrice,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 mv) {
        int256 tmpA = targetLeverage.sub(Constant.SIGNED_ONE);
        int256 tmpB = tmpA.wmul(indexPrice).wmul(positionAmount).add(targetLeverage.wmul(mc));
        int256 beforeSqrt = beta
            .wmul(indexPrice)
            .wmul(targetLeverage)
            .wmul(mc)
            .mul(positionAmount)
            .mul(4);
        beforeSqrt = beforeSqrt.add(tmpB.mul(tmpB));
        require(beforeSqrt >= 0, 'amm is unsafe when regress');
        mv = beta.sub(Constant.SIGNED_ONE).wmul(mc).mul(2);
        mv = mv.add(beforeSqrt.sqrt()).add(tmpB);
        mv = mv.wfrac(tmpA, tmpA.add(beta)).div(2);
    }

    function _shortVirtualMargin(
        int256 mc,
        int256 positionAmount,
        int256 indexPrice,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 mv) {
        int256 tmpA = indexPrice.wmul(positionAmount).mul(2);
        int256 tmpB = targetLeverage
            .add(Constant.SIGNED_ONE)
            .wmul(indexPrice)
            .wmul(positionAmount)
            .add(targetLeverage.wmul(mc));
        int256 beforeSqrt = tmpB.mul(tmpB).sub(beta.wmul(targetLeverage).wmul(tmpA).mul(tmpA));
        require(beforeSqrt >= 0, 'amm is unsafe when regress');
        mv = tmpB.sub(tmpA).add(beforeSqrt.sqrt());
        mv = mv.wfrac(targetLeverage.sub(Constant.SIGNED_ONE), targetLeverage).div(2);
    }

    function isAMMMarginSafe(
        int256 mc,
        int256 positionAmount,
        int256 indexPrice,
        int256 targetLeverage,
        int256 beta
    ) internal pure returns (bool) {
        if (positionAmount == 0 || (positionAmount > 0 && mc >= 0)) {
            return true;
        } else if (positionAmount > 0) {
            return indexPrice >= _longIndexLowerbound(mc, positionAmount, targetLeverage, beta);
        } else {
            return indexPrice <= _shortIndexUpperbound(mc, positionAmount, targetLeverage, beta);
        }
    }

    function _longIndexLowerbound(
        int256 mc,
        int256 positionAmount,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 lowerbound) {
        int256 t = targetLeverage.sub(Constant.SIGNED_ONE);
        lowerbound = t.add(beta).mul(beta);
        lowerbound = lowerbound.sqrt().mul(2).add(t).add(beta.mul(2));
        lowerbound = lowerbound.wfrac(targetLeverage, positionAmount).wfrac(mc.neg(), t.wmul(t));
    }

    function _shortIndexUpperbound(
        int256 mc,
        int256 positionAmount,
        int256 targetLeverage,
        int256 beta
    ) private pure returns (int256 upperbound) {
        upperbound = beta.mul(targetLeverage).sqrt().mul(2).add(targetLeverage).add(
            Constant.SIGNED_ONE
        );
        upperbound = targetLeverage.wfrac(mc, positionAmount.neg()).wdiv(upperbound);
    }
}
