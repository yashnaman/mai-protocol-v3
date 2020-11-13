// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../Type.sol";
import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMCommon.sol";

library AMMTrade {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeMath for uint256;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    function calculateDeltaMargin(
        FundingState storage fundingState,
        RiskParameter storage riskParameter,
        MarginAccount storage ammAccount,
        int256 indexPrice,
        int256 tradingAmount
    ) internal view returns (int256 deltaMargin) {
        require(tradingAmount != 0, "no zero trade amount");
        int256 cashBalance = AMMCommon.calculateCashBalance(
            ammAccount,
            fundingState.unitAccFundingLoss
        );
        int256 positionAmount = ammAccount.positionAmount;
        (int256 closingAmount, int256 openingAmount) = Utils.splitAmount(
            positionAmount,
            tradingAmount
        );
        // TC说这个不对
        deltaMargin = deltaMargin.add(
            closePosition(
                riskParameter,
                indexPrice,
                cashBalance,
                positionAmount,
                closingAmount
            )
        );
        deltaMargin = deltaMargin.add(
            openPosition(
                riskParameter,
                indexPrice,
                cashBalance.add(deltaMargin),
                positionAmount.add(closingAmount),
                openingAmount
            )
        );
        int256 spread = riskParameter.halfSpreadRate.value.wmul(deltaMargin);
        deltaMargin > 0 ? deltaMargin.add(spread) : deltaMargin.sub(spread);
    }

    function calculateRemovingLiquidityPenalty(
        FundingState storage fundingState,
        RiskParameter storage riskParameter,
        MarginAccount storage ammAccount,
        int256 indexPrice,
        int256 amount
    ) internal view returns (int256 penalty) {
        int256 cashBalance = AMMCommon.calculateCashBalance(
            ammAccount,
            fundingState.unitAccFundingLoss
        );
        int256 positionAmount = ammAccount.positionAmount;
        require(
            _isAMMMarginSafe(
                cashBalance,
                positionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                riskParameter.beta1.value
            ),
            "unsafe before trade"
        );
        int256 newCashBalance = cashBalance.sub(amount);
        require(
            _isAMMMarginSafe(
                newCashBalance,
                positionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                riskParameter.beta1.value
            ),
            "unsafe before trade"
        );
        (, int256 m0) = AMMCommon.regress(
            cashBalance,
            positionAmount,
            indexPrice,
            riskParameter.virtualLeverage.value,
            riskParameter.beta1.value
        );
        (, int256 newM0) = AMMCommon.regress(
            newCashBalance,
            positionAmount,
            indexPrice,
            riskParameter.virtualLeverage.value,
            riskParameter.beta1.value
        );
        penalty = m0.sub(newM0).sub(
            riskParameter.virtualLeverage.value.wmul(amount)
        );
        penalty = penalty < 0 ? 0 : amount;
    }

    function openPosition(
        RiskParameter storage riskParameter,
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 tradingAmount
    ) private view returns (int256 deltaMargin) {
        if (tradingAmount == 0) {
            return 0;
        }
        require(
            _isAMMMarginSafe(
                cashBalance,
                positionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                riskParameter.beta1.value
            ),
            "unsafe before trade"
        );
        (int256 mv, int256 m0) = AMMCommon.regress(
            cashBalance,
            positionAmount,
            indexPrice,
            riskParameter.virtualLeverage.value,
            riskParameter.beta1.value
        );
        if (positionAmount > 0 || (positionAmount == 0 && tradingAmount > 0)) {
            deltaMargin = calculateLongDeltaMargin(
                m0,
                cashBalance.add(mv),
                positionAmount,
                positionAmount.add(tradingAmount),
                indexPrice,
                riskParameter.beta1.value
            );
        } else {
            deltaMargin = calculateShortDeltaMargin(
                m0,
                positionAmount,
                positionAmount.add(tradingAmount),
                indexPrice,
                riskParameter.beta1.value
            );
        }
        // TODO: tc 说这个不对
        int256 newCashBalance = cashBalance.add(deltaMargin);
        int256 newPositionAmount = positionAmount.add(tradingAmount);
        require(
            _isAMMMarginSafe(
                newCashBalance,
                newPositionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                riskParameter.beta1.value
            ),
            "unsafe before trade"
        );
        (int256 newMV, ) = AMMCommon.regress(
            newCashBalance,
            newPositionAmount,
            indexPrice,
            riskParameter.virtualLeverage.value,
            riskParameter.beta1.value
        );
        require(newMV == mv, "unsafe after trade (origin margin change)");
    }

    function closePosition(
        RiskParameter storage riskParameter,
        int256 indexPrice,
        int256 cashBalance,
        int256 positionAmount,
        int256 tradingAmount
    ) private view returns (int256 deltaMargin) {
        require(positionAmount != 0, "zero position before close");
        if (tradingAmount == 0) {
            return 0;
        }
        int256 closingBeta = riskParameter.beta2.value;
        if (
            _isAMMMarginSafe(
                cashBalance,
                positionAmount,
                indexPrice,
                riskParameter.virtualLeverage.value,
                closingBeta
            )
        ) {
            (int256 mv, int256 m0) = AMMCommon.regress(
                indexPrice,
                riskParameter.virtualLeverage.value,
                cashBalance,
                positionAmount,
                closingBeta
            );
            if (positionAmount > 0) {
                deltaMargin = calculateLongDeltaMargin(
                    m0,
                    cashBalance.add(mv),
                    positionAmount,
                    positionAmount.add(tradingAmount),
                    indexPrice,
                    closingBeta
                );
            } else {
                deltaMargin = calculateShortDeltaMargin(
                    m0,
                    positionAmount,
                    positionAmount.add(tradingAmount),
                    indexPrice,
                    closingBeta
                );
            }
        } else {
            deltaMargin = indexPrice.wmul(tradingAmount);
        }
    }

    function calculateLongDeltaMargin(
        int256 m0,
        int256 ma,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 beta
    ) public pure returns (int256 deltaMargin) {
        int256 a = Constant.SIGNED_ONE.sub(beta).wmul(ma).mul(2);
        int256 b = positionAmount2.sub(positionAmount1).wmul(indexPrice);
        b = a.div(2).sub(b).wmul(ma);
        b = b.sub(beta.wmul(m0).wmul(m0));
        int256 beforeSqrt = beta.wmul(a).wmul(ma).wmul(m0).mul(m0).mul(2);
        beforeSqrt = beforeSqrt.add(b.mul(b));
        deltaMargin = beforeSqrt.sqrt().add(b).wdiv(a).sub(ma);
    }

    function calculateShortDeltaMargin(
        int256 m0,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice,
        int256 beta
    ) public pure returns (int256 deltaMargin) {
        deltaMargin = beta.wmul(m0).wmul(m0);
        deltaMargin = deltaMargin.wdiv(
            positionAmount1.wmul(indexPrice).add(m0)
        );
        deltaMargin = deltaMargin.wdiv(
            positionAmount2.wmul(indexPrice).add(m0)
        );
        deltaMargin = deltaMargin.add(Constant.SIGNED_ONE).sub(beta);
        deltaMargin = deltaMargin
            .wmul(indexPrice)
            .wmul(positionAmount2.sub(positionAmount1))
            .neg();
    }

    function _isAMMMarginSafe(
        int256 cashBalance,
        int256 positionAmount,
        int256 indexPrice,
        int256 virtualLeverage,
        int256 beta
    ) private pure returns (bool) {
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
