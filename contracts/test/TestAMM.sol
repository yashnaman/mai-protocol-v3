// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../module/AMMModule.sol";

contract TestAMM {
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    // using MarginModule for Core;
    using OracleModule for Perpetual;

    Core core;

    constructor() {
        core.perpetuals.push();
        core.perpetuals.push();
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
        core.perpetuals[0].id = 0;
        core.perpetuals[0].state = PerpetualState.NORMAL;
        core.perpetuals[0].unitAccumulativeFunding = unitAccumulativeFunding;
        core.perpetuals[0].halfSpread.value = halfSpread;
        core.perpetuals[0].openSlippageFactor.value = openSlippageFactor;
        core.perpetuals[0].closeSlippageFactor.value = closeSlippageFactor;
        core.perpetuals[0].maxLeverage.value = maxLeverage;
        core.poolCashBalance = cashBalance;
        core.perpetuals[0].marginAccounts[address(this)].positionAmount = positionAmount1;
        core.perpetuals[0].indexPriceData.price = indexPrice1;

        core.perpetuals[1].id = 1;
        core.perpetuals[1].state = PerpetualState.NORMAL;
        core.perpetuals[1].unitAccumulativeFunding = unitAccumulativeFunding;
        core.perpetuals[1].halfSpread.value = halfSpread;
        core.perpetuals[1].openSlippageFactor.value = openSlippageFactor;
        core.perpetuals[1].closeSlippageFactor.value = closeSlippageFactor;
        core.perpetuals[1].maxLeverage.value = maxLeverage;
        core.perpetuals[1].marginAccounts[address(this)].positionAmount = positionAmount2;
        core.perpetuals[1].indexPriceData.price = indexPrice2;
    }

    function setConfig(address collateral, address shareToken, uint256 scaler) public {
        core.collateral = collateral;
        core.shareToken = shareToken;
        core.scaler = scaler;
    }

    function isAMMMarginSafe() public view returns (bool) {
        Perpetual storage perpetual = core.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return AMMModule.isAMMMarginSafe(context, perpetual.openSlippageFactor.value);
    }

    function regress() public view returns (int256) {
        Perpetual storage perpetual = core.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return AMMModule.regress(context, perpetual.openSlippageFactor.value);
    }


    function deltaMargin(int256 amount)
        public
        view
        returns (int256 deltaMargin)
    {
        Perpetual storage perpetual = core.perpetuals[0];
        deltaMargin = AMMModule._deltaMargin(
            regress(),
            perpetual.marginAccounts[address(this)].positionAmount,
            perpetual.marginAccounts[address(this)].positionAmount.add(amount),
            perpetual.indexPrice(),
            perpetual.openSlippageFactor.value
        );
    }

    function maxPosition(bool isLongSide) public view returns (int256) {
        Perpetual storage perpetual = core.perpetuals[0];
        AMMModule.Context memory context = AMMModule.prepareContext(core, 0);
        return
            AMMModule._maxPosition(
                context,
                regress(),
                perpetual.maxLeverage.value,
                perpetual.openSlippageFactor.value,
                isLongSide
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

    function addLiquidity(int256 marginToAdd)
        public
        returns (int256 share)
    {
        AMMModule.addLiquidity(core, marginToAdd);
    }

    function removeLiquidity(int256 shareToRemove)
        public
        returns (int256 marginToRemove)
    {
        AMMModule.removeLiquidity(core, shareToRemove);
    }
}
