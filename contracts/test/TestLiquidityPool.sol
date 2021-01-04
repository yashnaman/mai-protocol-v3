// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/AMMModule.sol";
import "../module/PerpetualModule.sol";
import "../module/LiquidityPoolModule.sol";

import "../Type.sol";
import "./TestPerpetual.sol";

contract TestLiquidityPool is TestPerpetual {
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    // debug
    function setGovernor(address governor) public {
        _liquidityPool.governor = governor;
    }

    function setShareToken(address shareToken) public {
        _liquidityPool.shareToken = shareToken;
    }

    function setFactory(address governor) public {
        _liquidityPool.governor = governor;
    }

    function setCollateralToken(address collateralToken, uint256 scaler) public {
        _liquidityPool.collateralToken = collateralToken;
        _liquidityPool.scaler = scaler;
    }

    function setPoolCash(int256 amount) public {
        _liquidityPool.poolCash = amount;
    }

    function setFundingTime(uint256 fundingTime) public {
        _liquidityPool.fundingTime = fundingTime;
    }

    function getFundingTime() public view returns (uint256) {
        return _liquidityPool.fundingTime;
    }

    function getPriceUpdateTime() public view returns (uint256) {
        return _liquidityPool.priceUpdateTime;
    }

    // raw
    function getAvailablePoolCash(uint256 exclusiveIndex)
        public
        view
        returns (int256 availablePoolCash)
    {
        availablePoolCash = _liquidityPool.getAvailablePoolCash(exclusiveIndex);
    }

    function isAMMMarginSafe(uint256 perpetualIndex) public view returns (bool isSafe) {
        isSafe = _liquidityPool.isAMMMarginSafe(perpetualIndex);
    }

    function setLiquidityPoolParameter(bytes32 key, int256 newValue) public {
        _liquidityPool.setLiquidityPoolParameter(key, newValue);
    }

    function setPerpetualBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) public {
        _liquidityPool.setPerpetualBaseParameter(perpetualIndex, key, newValue);
    }

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) public {
        _liquidityPool.setPerpetualRiskParameter(perpetualIndex, key, newValue, minValue, maxValue);
    }

    function updatePerpetualRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        _liquidityPool.updatePerpetualRiskParameter(perpetualIndex, key, newValue);
    }

    function setEmergencyState(uint256 perpetualIndex) public virtual override {
        _liquidityPool.setEmergencyState(perpetualIndex);
    }

    function transferOperator(address newOperator) public {
        _liquidityPool.transferOperator(newOperator);
    }

    function claimOperator(address claimer) public {
        _liquidityPool.claimOperator(claimer);
    }

    function revokeOperator() public {
        _liquidityPool.revokeOperator();
    }

    // state
    function updateFundingState(uint256 currentTime) public {
        _liquidityPool.updateFundingState(currentTime);
    }

    function updateFundingRate() public {
        _liquidityPool.updateFundingRate();
    }

    function updatePrice(uint256 currentTime) public virtual override {
        _liquidityPool.updatePrice(currentTime);
    }

    function donateInsuranceFundPayable(uint256 perpetualIndex, int256 amount) public payable {
        _liquidityPool.donateInsuranceFund(perpetualIndex, amount);
    }

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.deposit(perpetualIndex, trader, amount, extData, signature);
    }

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.withdraw(perpetualIndex, trader, amount, extData, signature);
    }

    function clear(
        uint256 perpetualIndex,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.clear(perpetualIndex, extData, signature);
    }

    function settle(
        uint256 perpetualIndex,
        address trader,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.settle(perpetualIndex, trader, extData, signature);
    }

    function addLiquidity(
        address trader,
        int256 cashToAdd,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.addLiquidity(trader, cashToAdd, extData, signature);
    }

    function removeLiquidity(
        address trader,
        int256 shareToRemove,
        bytes32 extData,
        bytes calldata signature
    ) public {
        _liquidityPool.addLiquidity(trader, shareToRemove, extData, signature);
    }

    function increaseFee(address account, int256 amount) public {
        _liquidityPool.increaseFee(account, amount);
    }

    function claimFee(address account, int256 amount) public {
        _liquidityPool.claimFee(account, amount);
    }

    function rebalanceFrom(uint256 perpetualIndex) public {
        _liquidityPool.rebalanceFrom(perpetualIndex);
    }

    function increasePoolCash(int256 amount) internal {
        _liquidityPool.increasePoolCash(amount);
    }

    function decreasePoolCash(int256 amount) internal {
        _liquidityPool.decreasePoolCash(amount);
    }

    function isAuthorized(
        address trader,
        address grantor,
        uint256 privilege
    ) public view returns (bool isGranted) {
        isGranted = _liquidityPool.isAuthorized(trader, grantor, privilege);
    }
}
