// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/AMMModule.sol";
import "../module/PerpetualModule.sol";

import "../Perpetual.sol";
import "../Type.sol";

contract TestPerpetual is Perpetual {
    using AMMModule for LiquidityPoolStorage;
    using PerpetualModule for PerpetualStorage;

    function createPerpetual(
        address oracle,
        int256[9] calldata coreParams,
        int256[6] calldata riskParams
    ) external {
        uint256 perpetualIndex = _liquidityPool.perpetuals.length;
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals.push();
        perpetual.initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            riskParams,
            riskParams
        );
    }

    function setCollateralToken(address collateralToken, uint256 scaler) public {
        _liquidityPool.collateralToken = collateralToken;
        _liquidityPool.scaler = scaler;
    }

    function setIndexPrice(uint256 perpetualIndex, int256 price) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.indexPriceData.price = price;
        perpetual.indexPriceData.time = block.timestamp;
    }

    function setMarkPrice(uint256 perpetualIndex, int256 price) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.markPriceData.price = price;
        perpetual.markPriceData.time = block.timestamp;
    }

    function setState(uint256 perpetualIndex, PerpetualState state) public {
        _liquidityPool.perpetuals[perpetualIndex].state = state;
    }

    function setPoolCash(int256 amount) public {
        _liquidityPool.poolCash = amount;
    }

    function setFundingTime(uint256 fundingTime) public {
        _liquidityPool.fundingTime = fundingTime;
    }

    function setMarginAccount(
        uint256 perpetualIndex,
        address trader,
        int256 cash,
        int256 position
    ) external {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.marginAccounts[trader].cash = cash;
        perpetual.marginAccounts[trader].position = position;
    }

    function getUnitAccumulativeFunding(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].unitAccumulativeFunding;
    }

    function setUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding)
        public
    {
        _liquidityPool.perpetuals[perpetualIndex].unitAccumulativeFunding = unitAccumulativeFunding;
    }

    function getFundingRate(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].fundingRate;
    }

    function setFundingRate(uint256 perpetualIndex, int256 fundingRate) public {
        _liquidityPool.perpetuals[perpetualIndex].fundingRate = fundingRate;
    }

    function updateFundingState(uint256 perpetualIndex, int256 timeElapsed)
        public
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateFundingState(timeElapsed);
        return perpetual.unitAccumulativeFunding;
    }

    function updateFundingRate(uint256 perpetualIndex) public returns (int256) {
        AMMModule.Context memory context = _liquidityPool.prepareContext();
        int256 poolMargin = AMMModule.isAMMMarginSafe(context, 0)
            ? AMMModule.regress(context, 0)
            : 0;
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateFundingRate(poolMargin);
        return perpetual.fundingRate;
    }

    function getDonatedInsuranceFund(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.donatedInsuranceFund;
    }

    function getTotalCollateral(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.totalCollateral;
    }

    function setTotalCollateral(uint256 perpetualIndex, int256 amount) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.totalCollateral = amount;
    }

    function setEmergencyState(uint256 perpetualIndex) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.setEmergencyState();
    }

    function registerActiveAccount(uint256 perpetualIndex, address account) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.registerActiveAccount(account);
    }

    function redemptionRateWithoutPosition(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.redemptionRateWithoutPosition;
    }

    function redemptionRateWithPosition(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.redemptionRateWithPosition;
    }
}
