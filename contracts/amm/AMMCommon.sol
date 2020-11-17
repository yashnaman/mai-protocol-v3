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
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 virtualLeverage,
        int256 beta
    ) internal pure returns (int256 mv, int256 m0) {
        if (positionAmount == 0) {
            mv = virtualLeverage.sub(Constant.SIGNED_ONE).wmul(cashBalance);
        } else if (positionAmount > 0) {
            mv = calculateLongVirtualMargin(
                cashBalance,
                positionAmount,
                indexPrice,
                virtualLeverage,
                beta
            );
        } else {
            mv = calculateShortVirtualMargin(
                cashBalance,
                positionAmount,
                indexPrice,
                virtualLeverage,
                beta
            );
        }
        m0 = mv.wfrac(
            virtualLeverage,
            virtualLeverage.sub(Constant.SIGNED_ONE)
        );
    }

    function calculateLongVirtualMargin(
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 virtualLeverage,
        int256 beta
    ) internal pure returns (int256 mv) {
        int256 t = virtualLeverage.sub(Constant.SIGNED_ONE);
        int256 b = t.wmul(indexPrice.wmul(positionAmount)).add(
            virtualLeverage.wmul(cashBalance)
        );
        int256 beforeSqrt = beta
            .wmul(indexPrice)
            .wmul(virtualLeverage.wmul(cashBalance))
            .mul(positionAmount)
            .mul(4);
        beforeSqrt = beforeSqrt.add(b.mul(b));
        mv = beta.sub(Constant.SIGNED_ONE).wmul(cashBalance).mul(2);
        mv = mv.add(beforeSqrt.sqrt()).add(b);
        mv = mv.wfrac(t, t.add(beta)).div(2);
    }

    function calculateShortVirtualMargin(
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 virtualLeverage,
        int256 beta
    ) internal pure returns (int256 mv) {
        int256 a = indexPrice.wmul(positionAmount).mul(2);
        int256 b = virtualLeverage
            .add(Constant.SIGNED_ONE)
            .wmul(indexPrice.wmul(positionAmount))
            .add(virtualLeverage.wmul(cashBalance));
        int256 beforeSqrt = b.mul(b).sub(
            beta.wmul(virtualLeverage).wmul(a).mul(a)
        );
        mv = b.sub(a).add(beforeSqrt.sqrt());
        mv = mv
            .wfrac(virtualLeverage.sub(Constant.SIGNED_ONE), virtualLeverage)
            .div(2);
    }

    function calculateCashBalance(
        MarginAccount storage account,
        int256 unitAccFundingLoss
    ) internal view returns (int256) {
        return
            account.positionAmount.wmul(unitAccFundingLoss).sub(
                account.cashBalance
            );
    }

    function isAMMMarginSafe(
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 virtualLeverage,
        int256 beta
    ) internal pure returns (bool) {
        if (positionAmount == 0 || (positionAmount > 0 && cashBalance < 0)) {
            return true;
        }
        if (positionAmount > 0) {
            return
                indexPrice >=
                _indexLowerbound(
                    cashBalance,
                    positionAmount,
                    virtualLeverage,
                    beta
                );
        } else {
            return
                indexPrice <=
                _indexUpperbound(
                    cashBalance,
                    positionAmount,
                    virtualLeverage,
                    beta
                );
        }
    }

    function _indexLowerbound(
        int256 cashBalance,
        int256 positionAmount,
        int256 virtualLeverage,
        int256 beta
    ) private pure returns (int256 lowerbound) {
        int256 t = virtualLeverage.sub(Constant.SIGNED_ONE);
        lowerbound = t.add(beta).mul(beta);
        lowerbound = lowerbound.sqrt().mul(2).add(t).add(beta.mul(2));
        lowerbound = lowerbound.wfrac(virtualLeverage, positionAmount).wfrac(
            cashBalance.neg(),
            t.wmul(t)
        );
    }

    function _indexUpperbound(
        int256 cashBalance,
        int256 positionAmount,
        int256 virtualLeverage,
        int256 beta
    ) private pure returns (int256 upperbound) {
        upperbound = beta
            .mul(virtualLeverage)
            .sqrt()
            .mul(2)
            .add(virtualLeverage)
            .add(Constant.SIGNED_ONE);
        upperbound = virtualLeverage
            .wfrac(cashBalance, positionAmount.neg())
            .wdiv(upperbound);
    }
}
