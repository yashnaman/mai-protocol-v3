// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";

import "../module/AMMTradeModule.sol";
import "../module/AMMCommon.sol";

contract TestAMM {
    using SignedSafeMath for int256;
	using MarginModule for Core;
	using OracleModule for Core;

    Core core;

    function setParams(
        int256 unitAccumulativeFunding,
        int256 halfSpreadRate,
        int256 beta1,
        int256 beta2,
        int256 targetLeverage,
        int256 cashBalance,
        int256 positionAmount,
        int256 entryFundingLoss,
        int256 _indexPrice
    ) public {
        core.unitAccumulativeFunding = unitAccumulativeFunding;
        core.halfSpreadRate.value = halfSpreadRate;
        core.beta1.value = beta1;
        core.beta2.value = beta2;
        core.targetLeverage.value = targetLeverage;
        core.marginAccounts[address(this)].cashBalance = cashBalance;
        core.marginAccounts[address(this)].positionAmount = positionAmount;
        core.marginAccounts[address(this)].entryFundingLoss = entryFundingLoss;
        core.indexPriceData.price = _indexPrice;
    }

    function isAMMMarginSafe(
        int256 beta
    ) public view returns (bool) {
        int256 mc = core.cashBalance(address(this));
        return AMMCommon.isAMMMarginSafe(mc, core.marginAccounts[address(this)].positionAmount, core.indexPrice(), core.targetLeverage.value, beta);
    }

    function regress(
        int256 beta
    ) public view returns (int256 mv, int256 m0) {
        int256 mc = core.cashBalance(address(this));
        (mv, m0) = AMMCommon.regress(mc, core.marginAccounts[address(this)].positionAmount, core.indexPrice(), core.targetLeverage.value, beta);
    }

    function longDeltaMargin(
        int256 positionAmount2,
        int256 beta
    ) public view returns (int256 deltaMargin) {
        int256 mc = core.cashBalance(address(this));
        (int256 mv, int256 m0) = regress(beta);
        deltaMargin = AMMTradeModule.longDeltaMargin(m0, mc.add(mv), core.marginAccounts[address(this)].positionAmount, positionAmount2, core.indexPrice(), beta);
    }

    function shortDeltaMargin(
        int256 positionAmount2,
        int256 beta
    ) public view returns (int256 deltaMargin) {
        int256 mc = core.cashBalance(address(this));
        (, int256 m0) = regress(beta);
        deltaMargin = AMMTradeModule.shortDeltaMargin(m0, core.marginAccounts[address(this)].positionAmount, positionAmount2, core.indexPrice(), beta);
    }

    function maxLongPosition(
        int256 beta
    ) public view returns (int256) {
        (, int256 m0) = regress(beta);
        return AMMTradeModule._maxLongPosition(m0, core.indexPrice(), beta, core.targetLeverage.value);
    }

    function maxShortPosition(
        int256 beta
    ) public view returns (int256) {
        (, int256 m0) = regress(beta);
        return AMMTradeModule._maxShortPosition(m0, core.indexPrice(), beta, core.targetLeverage.value);
    }

    function tradeWithAMM(
        int256 tradingAmount,
        bool partialFill
    ) public view returns (int256 deltaMargin, int256 deltaPosition) {
        (deltaMargin, deltaPosition) = AMMTradeModule.tradeWithAMM(core, tradingAmount, partialFill);
    }

    function addLiquidity(
        int256 shareTotalSupply,
        int256 marginToAdd
    ) public view returns (int256 share) {
        share = AMMTradeModule.addLiquidity(core, shareTotalSupply, marginToAdd);
    }

    function removeLiquidity(
        int256 shareTotalSupply,
        int256 shareToRemove
    ) public view returns (int256 marginToRemove) {
        marginToRemove = AMMTradeModule.removeLiquidity(core, shareTotalSupply, shareToRemove);
    }

}

