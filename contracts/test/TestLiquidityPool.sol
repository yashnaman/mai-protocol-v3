// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/AMMModule.sol";
import "../module/PerpetualModule.sol";
import "../module/LiquidityPoolModule.sol";
import "../module/CollateralModule.sol";

import "../Type.sol";
import "./TestPerpetual.sol";

contract TestLiquidityPool is TestPerpetual {
    using PerpetualModule for PerpetualStorage;
    using CollateralModule for LiquidityPoolStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;

    // debug
    function setGovernor(address governor) public {
        _liquidityPool.governor = governor;
    }

    function getOperator() public view returns (address) {
        return _liquidityPool.operator;
    }

    function getTransferringOperator() public view returns (address) {
        return _liquidityPool.transferringOperator;
    }

    function setOperator(address operator) public {
        _liquidityPool.operator = operator;
    }

    function setShareToken(address shareToken) public {
        _liquidityPool.shareToken = shareToken;
    }

    function setFactory(address creator) public {
        _liquidityPool.creator = creator;
    }

    function setCollateralToken(address collateralToken, uint256 collateralDecimals) public {
        _liquidityPool.initializeCollateral(collateralToken, collateralDecimals);
    }

    function getPoolCash() public view returns (int256) {
        return _liquidityPool.poolCash;
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

    function runLiquidityPool() public {
        _liquidityPool.runLiquidityPool();
    }

    function getAvailablePoolCash(uint256 exclusiveIndex)
        public
        view
        returns (int256 availablePoolCash)
    {
        availablePoolCash = _liquidityPool.getAvailablePoolCash(exclusiveIndex);
    }

    function isAMMMaintenanceSafe(uint256 perpetualIndex) public returns (bool isSafe) {
        isSafe = _liquidityPool.isAMMMaintenanceSafe(perpetualIndex);
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

    function claimOperator() public {
        _liquidityPool.claimOperator(msg.sender);
    }

    function revokeOperator() public {
        _liquidityPool.revokeOperator();
    }

    // state
    function updateFundingStateP(uint256 currentTime) public {
        _liquidityPool.updateFundingState(currentTime);
    }

    function updateFundingRateP() public {
        _liquidityPool.updateFundingRate();
    }

    function updatePrice(uint256 currentTime) public virtual override {
        _liquidityPool.updatePrice(currentTime);
    }

    function donateInsuranceFundP(uint256 perpetualIndex, int256 amount) public payable {
        _liquidityPool.donateInsuranceFund(perpetualIndex, amount);
    }

    function depositP(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public payable {
        _liquidityPool.deposit(perpetualIndex, trader, amount);
    }

    function withdrawP(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        _liquidityPool.withdraw(perpetualIndex, trader, amount);
    }

    function clearP(uint256 perpetualIndex) public {
        _liquidityPool.clear(perpetualIndex);
    }

    function settleP(uint256 perpetualIndex, address trader) public {
        _liquidityPool.settle(perpetualIndex, trader);
    }

    function addLiquidity(address trader, int256 cashToAdd) public {
        _liquidityPool.addLiquidity(trader, cashToAdd);
    }

    function removeLiquidity(address trader, int256 shareToRemove) public {
        _liquidityPool.removeLiquidity(trader, shareToRemove);
    }

    function increaseFee(address account, int256 amount) public {
        _liquidityPool.increaseFee(account, amount);
    }

    function claimFee(address account, int256 amount) public {
        _liquidityPool.claimFee(account, amount);
    }

    function rebalance(uint256 perpetualIndex) public {
        _liquidityPool.rebalance(perpetualIndex);
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
