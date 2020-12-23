// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../module/AMMModule.sol";

contract TestAMM {
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    // using MarginModule for LiquidityPoolStorage;
    using OracleModule for PerpetualStorage;

    LiquidityPoolStorage liquidityPool;

    constructor() {
        liquidityPool.perpetuals.push();
        liquidityPool.perpetuals.push();
    }

    function setParams(
        int256 unitAccumulativeFunding,
        int256 halfSpread,
        int256 openSlippageFactor,
        int256 closeSlippageFactor,
        int256 ammMaxLeverage,
        int256 cashBalance,
        int256 positionAmount1,
        int256 positionAmount2,
        int256 indexPrice1,
        int256 indexPrice2
    ) public {
        liquidityPool.perpetuals[0].id = 0;
        liquidityPool.perpetuals[0].state = PerpetualState.NORMAL;
        liquidityPool.perpetuals[0].unitAccumulativeFunding = unitAccumulativeFunding;
        liquidityPool.perpetuals[0].halfSpread.value = halfSpread;
        liquidityPool.perpetuals[0].openSlippageFactor.value = openSlippageFactor;
        liquidityPool.perpetuals[0].closeSlippageFactor.value = closeSlippageFactor;
        liquidityPool.perpetuals[0].ammMaxLeverage.value = ammMaxLeverage;
        liquidityPool.poolCashBalance = cashBalance;
        liquidityPool.perpetuals[0].marginAccounts[address(this)].positionAmount = positionAmount1;
        liquidityPool.perpetuals[0].indexPriceData.price = indexPrice1;

        liquidityPool.perpetuals[1].id = 1;
        liquidityPool.perpetuals[1].state = PerpetualState.NORMAL;
        liquidityPool.perpetuals[1].unitAccumulativeFunding = unitAccumulativeFunding;
        liquidityPool.perpetuals[1].halfSpread.value = halfSpread;
        liquidityPool.perpetuals[1].openSlippageFactor.value = openSlippageFactor;
        liquidityPool.perpetuals[1].closeSlippageFactor.value = closeSlippageFactor;
        liquidityPool.perpetuals[1].ammMaxLeverage.value = ammMaxLeverage;
        liquidityPool.perpetuals[1].marginAccounts[address(this)].positionAmount = positionAmount2;
        liquidityPool.perpetuals[1].indexPriceData.price = indexPrice2;
    }

    function setConfig(address collateral, address shareToken, uint256 scaler) public {
        liquidityPool.collateral = collateral;
        liquidityPool.shareToken = shareToken;
        liquidityPool.scaler = scaler;
    }

    function isAMMMarginSafe() public view returns (bool) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(liquidityPool, 0);
        return AMMModule.isAMMMarginSafe(context, perpetual.openSlippageFactor.value);
    }

    function regress() public view returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(liquidityPool, 0);
        return AMMModule.regress(context, perpetual.openSlippageFactor.value);
    }


    function deltaMargin(int256 amount)
        public
        view
        returns (int256 deltaMargin)
    {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[0];
        deltaMargin = AMMModule._deltaMargin(
            regress(),
            perpetual.marginAccounts[address(this)].positionAmount,
            perpetual.marginAccounts[address(this)].positionAmount.add(amount),
            perpetual.getIndexPrice(),
            perpetual.openSlippageFactor.value
        );
    }

    function maxPosition(bool isLongSide) public view returns (int256) {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(liquidityPool, 0);
        return
            AMMModule._maxPosition(
                context,
                regress(),
                perpetual.ammMaxLeverage.value,
                perpetual.openSlippageFactor.value,
                isLongSide
            );
    }

    function tradeWithAMM(int256 tradeAmount, bool partialFill)
        public
        view
        returns (int256 deltaMargin, int256 deltaPosition)
    {
        (deltaMargin, deltaPosition) = AMMModule.tradeWithAMM(
            liquidityPool,
            0,
            tradeAmount,
            partialFill
        );
    }

    function addLiquidity(int256 marginToAdd)
        public
    {
        AMMModule.addLiquidity(liquidityPool, marginToAdd);
    }

    function removeLiquidity(int256 shareToRemove)
        public
    {
        AMMModule.removeLiquidity(liquidityPool, shareToRemove);
    }
}
