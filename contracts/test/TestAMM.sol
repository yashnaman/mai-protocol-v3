// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../module/AMMModule.sol";

contract TestAMM {
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    // using MarginModule for Core;
    // using OracleModule for Core;

    Core core;

    constructor() {
        core.markets.push();
        core.markets.push();
    }

    function setParams(
        int256 unitAccumulativeFunding,
        int256 halfSpread,
        int256 openSlippageFactor,
        int256 closeSlippageFactor,
        int256 maxLeverage,
        int256 cashBalance,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice1,
        int256 indexPrice2
    ) public {
        core.markets[0].id = "0x0";
        core.markets[0].state = MarketState.NORMAL;
        core.markets[0].unitAccumulativeFunding = unitAccumulativeFunding;
        core.markets[0].halfSpread.value = halfSpread;
        core.markets[0].openSlippageFactor.value = openSlippageFactor;
        core.markets[0].closeSlippageFactor.value = closeSlippageFactor;
        core.markets[0].maxLeverage.value = maxLeverage;
        core.liquidityPoolCashBalance = cashBalance;
        core.markets[0].marginAccounts[address(this)].positionAmount = positionAmount1;
        core.markets[0].indexPriceData.price = indexPrice1;

        core.markets[1].id = "0x1";
        core.markets[1].state = MarketState.NORMAL;
        core.markets[1].unitAccumulativeFunding = unitAccumulativeFunding;
        core.markets[1].halfSpread.value = halfSpread;
        core.markets[1].openSlippageFactor.value = openSlippageFactor;
        core.markets[1].closeSlippageFactor.value = closeSlippageFactor;
        core.markets[1].maxLeverage.value = maxLeverage;
        core.markets[1].marginAccounts[address(this)].positionAmount = positionAmount2;
        core.markets[1].indexPriceData.price = indexPrice2;
    }

    function isAMMMarginSafe() public view returns (bool) {
        Market storage market = core.markets[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, market);
        return AMMModule.isAMMMarginSafe(context, market.openSlippageFactor.value);
    }

    function regress() public view returns (int256) {
        Market storage market = core.markets[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, market);
        return AMMModule.regress(context, market.openSlippageFactor.value);
    }

    /*
    function virtualM0() public view returns (int256) {
        int256 mc = core.availableCashBalance(address(this));
        int256 positionAmount = core.marginAccounts[address(this)].positionAmount;
        if (positionAmount > 0) {
            return
                AMMCommon.longVirtualM0(
                    mc,
                    positionAmount,
                    core.indexPrice(),
                    core.targetLeverage.value,
                    core.beta1.value
                );
        } else {
            return
                AMMCommon.shortVirtualM0(
                    mc,
                    positionAmount,
                    core.indexPrice(),
                    core.targetLeverage.value,
                    core.beta1.value
                );
        }
    }

    function longDeltaMargin(int256 positionAmount2, int256 beta)
        public
        view
        returns (int256 deltaMargin)
    {
        int256 mc = core.availableCashBalance(address(this));
        (int256 mv, int256 m0) = regress(beta);
        deltaMargin = AMMModule.longDeltaMargin(
            m0,
            mc.add(mv),
            core.marginAccounts[address(this)].positionAmount,
            positionAmount2,
            core.indexPrice(),
            beta
        );
    }

    function shortDeltaMargin(int256 positionAmount2, int256 beta)
        public
        view
        returns (int256 deltaMargin)
    {
        int256 mc = core.availableCashBalance(address(this));
        (, int256 m0) = regress(beta);
        deltaMargin = AMMModule.shortDeltaMargin(
            m0,
            core.marginAccounts[address(this)].positionAmount,
            positionAmount2,
            core.indexPrice(),
            beta
        );
    }

    function maxLongPosition(int256 beta) public view returns (int256) {
        (, int256 m0) = regress(beta);
        return
            AMMModule._maxLongPosition(m0, core.indexPrice(), beta, core.targetLeverage.value);
    }

    function maxShortPosition(int256 beta) public view returns (int256) {
        (, int256 m0) = regress(beta);
        return
            AMMModule._maxShortPosition(
                m0,
                core.indexPrice(),
                beta,
                core.targetLeverage.value
            );
    }

    function tradeWithAMM(int256 tradingAmount, bool partialFill)
        public
        view
        returns (int256 deltaMargin, int256 deltaPosition)
    {
        (deltaMargin, deltaPosition) = AMMModule.tradeWithAMM(
            core,
            tradingAmount,
            partialFill
        );
    }

    function addLiquidity(int256 shareTotalSupply, int256 marginToAdd)
        public
        view
        returns (int256 share)
    {
        share = AMMModule.addLiquidity(core, shareTotalSupply, marginToAdd);
    }

    function removeLiquidity(int256 shareTotalSupply, int256 shareToRemove)
        public
        view
        returns (int256 marginToRemove)
    {
        marginToRemove = AMMModule.removeLiquidity(core, shareTotalSupply, shareToRemove);
    }
    */
}
