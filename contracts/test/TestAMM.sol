// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../module/AMMModule.sol";

contract TestAMM {
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    // using MarginModule for Core;
    using OracleModule for Market;

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
        core.markets[0].id = 0;
        core.markets[0].state = MarketState.NORMAL;
        core.markets[0].unitAccumulativeFunding = unitAccumulativeFunding;
        core.markets[0].halfSpread.value = halfSpread;
        core.markets[0].openSlippageFactor.value = openSlippageFactor;
        core.markets[0].closeSlippageFactor.value = closeSlippageFactor;
        core.markets[0].maxLeverage.value = maxLeverage;
        core.liquidityPoolCashBalance = cashBalance;
        core.markets[0].marginAccounts[address(this)].positionAmount = positionAmount1;
        core.markets[0].indexPriceData.price = indexPrice1;

        core.markets[1].id = 1;
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
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return AMMModule.isAMMMarginSafe(context, market.openSlippageFactor.value);
    }

    function regress() public view returns (int256) {
        Market storage market = core.markets[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return AMMModule.regress(context, market.openSlippageFactor.value);
    }


    function deltaMargin(int256 amount)
        public
        view
        returns (int256 deltaMargin)
    {
        Market storage market = core.markets[0];
        deltaMargin = AMMModule._deltaMargin(
            regress(),
            market.marginAccounts[address(this)].positionAmount,
            market.marginAccounts[address(this)].positionAmount.add(amount),
            market.indexPrice(),
            market.openSlippageFactor.value
        );
    }

    function maxPosition(Side side) public view returns (int256) {
        Market storage market = core.markets[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return
            AMMModule._maxPosition(
                context,
                regress(),
                market.maxLeverage.value,
                market.openSlippageFactor.value,
                side
            );
    }

    function tradeWithAMM(int256 tradingAmount, bool partialFill)
        public
        view
        returns (int256 deltaMargin, int256 deltaPosition)
    {
        (deltaMargin, deltaPosition) = AMMModule.tradeWithAMM(
            core,
            0,
            tradingAmount,
            partialFill
        );
    }

    function addLiquidity(int256 totalShare, int256 marginToAdd)
        public
        view
        returns (int256 share)
    {
        share = AMMModule.calculateShareToMint(core, totalShare, marginToAdd);
    }

    function removeLiquidity(int256 shareTotalSupply, int256 shareToRemove)
        public
        view
        returns (int256 marginToRemove)
    {
        marginToRemove = AMMModule.calculateCashToReturn(core, shareTotalSupply, shareToRemove);
    }
}
