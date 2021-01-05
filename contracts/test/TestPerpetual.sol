// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../module/AMMModule.sol";
import "../module/PerpetualModule.sol";
import "../module/MarginAccountModule.sol";

import "../Perpetual.sol";
import "../Storage.sol";
import "../Type.sol";

contract TestPerpetual is Storage {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using AMMModule for LiquidityPoolStorage;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;

    // ================ debug ============================================
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

    function setState(uint256 perpetualIndex, PerpetualState state) public {
        _liquidityPool.perpetuals[perpetualIndex].state = state;
    }

    function getState(uint256 perpetualIndex) public view returns (PerpetualState) {
        return _liquidityPool.perpetuals[perpetualIndex].state;
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

    function isTraderRegistered(uint256 perpetualIndex, address trader)
        public
        view
        returns (bool isRegistered)
    {
        isRegistered = _liquidityPool.perpetuals[perpetualIndex].activeAccounts.contains(trader);
    }

    function getActiveUserCount(uint256 perpetualIndex) public view returns (uint256 count) {
        count = _liquidityPool.perpetuals[perpetualIndex].activeAccounts.length();
    }

    function getMarginAccount(uint256 perpetualIndex, address trader)
        public
        view
        returns (int256 cash, int256 position)
    {
        MarginAccount storage account =
            _liquidityPool.perpetuals[perpetualIndex].marginAccounts[trader];
        cash = account.cash;
        position = account.position;
    }

    function getUnitAccumulativeFunding(uint256 perpetualIndex)
        public
        view
        returns (int256 unitAccumulativeFunding)
    {
        unitAccumulativeFunding = _liquidityPool.perpetuals[perpetualIndex].unitAccumulativeFunding;
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

    function getDonatedInsuranceFund(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.donatedInsuranceFund;
    }

    function setInsuranceFund(uint256 perpetualIndex, int256 amount) public {
        _liquidityPool.perpetuals[perpetualIndex].insuranceFund = amount;
    }

    function getInsuranceFund(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].insuranceFund;
    }

    function getTotalCollateral(uint256 perpetualIndex) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.totalCollateral;
    }

    function setTotalCollateral(uint256 perpetualIndex, int256 amount) public {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.totalCollateral = amount;
    }

    function getRedemptionRateWithoutPosition(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].redemptionRateWithoutPosition;
    }

    function getRedemptionRateWithPosition(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].redemptionRateWithPosition;
    }

    function getTotalMarginWithPosition(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].totalMarginWithPosition;
    }

    function getTotalMarginWithoutPosition(uint256 perpetualIndex) public view returns (int256) {
        return _liquidityPool.perpetuals[perpetualIndex].totalMarginWithoutPosition;
    }

    // raw interface
    function getMarkPrice(uint256 perpetualIndex) public view returns (int256 price) {
        price = _liquidityPool.perpetuals[perpetualIndex].getMarkPrice();
    }

    function getIndexPrice(uint256 perpetualIndex) public view returns (int256 price) {
        price = _liquidityPool.perpetuals[perpetualIndex].getIndexPrice();
    }

    function getRebalanceMargin(uint256 perpetualIndex)
        public
        view
        returns (int256 marginToRebalance)
    {
        marginToRebalance = _liquidityPool.perpetuals[perpetualIndex].getRebalanceMargin();
    }

    function setBaseParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) public {
        _liquidityPool.perpetuals[perpetualIndex].setBaseParameter(key, newValue);
    }

    function setRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) public {
        _liquidityPool.perpetuals[perpetualIndex].setRiskParameter(
            key,
            newValue,
            newMinValue,
            newMaxValue
        );
    }

    function updateRiskParameter(
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) public {
        _liquidityPool.perpetuals[perpetualIndex].updateRiskParameter(key, newValue);
    }

    function updateFundingState(uint256 perpetualIndex, int256 timeElapsed) public {
        _liquidityPool.perpetuals[perpetualIndex].updateFundingState(timeElapsed);
    }

    function updateFundingRate(uint256 perpetualIndex, int256 poolMargin) public {
        _liquidityPool.perpetuals[perpetualIndex].updateFundingState(poolMargin);
    }

    function setNormalState(uint256 perpetualIndex) public {
        _liquidityPool.perpetuals[perpetualIndex].setNormalState();
    }

    function setEmergencyState(uint256 perpetualIndex) public virtual {
        _liquidityPool.perpetuals[perpetualIndex].setEmergencyState();
    }

    function setClearedState(uint256 perpetualIndex) public {
        _liquidityPool.perpetuals[perpetualIndex].setClearedState();
    }

    function donateInsuranceFund(uint256 perpetualIndex, int256 amount) public payable {
        _liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(amount);
    }

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public payable returns (bool isInitialDeposit) {
        isInitialDeposit = _liquidityPool.perpetuals[perpetualIndex].deposit(trader, amount);
    }

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public returns (bool isLastWithdrawal) {
        isLastWithdrawal = _liquidityPool.perpetuals[perpetualIndex].withdraw(trader, amount);
    }

    function clear(uint256 perpetualIndex, address trader) public returns (bool isAllCleared) {
        isAllCleared = _liquidityPool.perpetuals[perpetualIndex].clear(trader);
    }

    function settle(uint256 perpetualIndex, address trader) public returns (int256 marginToReturn) {
        marginToReturn = _liquidityPool.perpetuals[perpetualIndex].settle(trader);
    }

    function updateInsuranceFund(uint256 perpetualIndex, int256 penaltyToFund)
        public
        returns (int256 penaltyToLP)
    {
        penaltyToLP = _liquidityPool.perpetuals[perpetualIndex].updateInsuranceFund(penaltyToFund);
    }

    function getNextActiveAccount(uint256 perpetualIndex) public view returns (address account) {
        account = _liquidityPool.perpetuals[perpetualIndex].getNextActiveAccount();
    }

    function getSettleableMargin(uint256 perpetualIndex, address trader)
        public
        view
        returns (int256 margin)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        margin = perpetual.getSettleableMargin(trader, perpetual.getMarkPrice());
    }

    function registerActiveAccount(uint256 perpetualIndex, address trader) public {
        _liquidityPool.perpetuals[perpetualIndex].registerActiveAccount(trader);
    }

    function deregisterActiveAccount(uint256 perpetualIndex, address trader) public {
        _liquidityPool.perpetuals[perpetualIndex].registerActiveAccount(trader);
    }

    function settleCollateral(uint256 perpetualIndex) public {
        _liquidityPool.perpetuals[perpetualIndex].settleCollateral();
    }

    // prettier-ignore
    function updatePrice(uint256 perpetualIndex) public virtual {
          _liquidityPool.perpetuals[perpetualIndex].updatePrice();
    }

    function increaseTotalCollateral(uint256 perpetualIndex, int256 amount) public {
        _liquidityPool.perpetuals[perpetualIndex].increaseTotalCollateral(amount);
    }

    function decreaseTotalCollateral(uint256 perpetualIndex, int256 amount) public {
        _liquidityPool.perpetuals[perpetualIndex].decreaseTotalCollateral(amount);
    }

    function validateBaseParameters(uint256 perpetualIndex) public view {
        _liquidityPool.perpetuals[perpetualIndex].validateBaseParameters();
    }

    function validateRiskParameters(uint256 perpetualIndex) public view {
        _liquidityPool.perpetuals[perpetualIndex].validateRiskParameters();
    }
}
