// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interface/IFactory.sol";

import "./module/FundingModule.sol";
import "./module/OracleModule.sol";
import "./module/MarginModule.sol";
import "./module/CollateralModule.sol";
import "./module/ParameterModule.sol";
import "./module/SettlementModule.sol";

import "./Type.sol";

contract Storage {
    using SafeMath for uint256;
    using CollateralModule for address;
    using FundingModule for Core;
    using MarginModule for Core;
    using OracleModule for Core;
    using ParameterModule for Core;
    using SettlementModule for Core;
    using ParameterModule for Option;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    Core internal _core;
    address internal _governor;
    address internal _shareToken;

    modifier syncState() {
        _core.updateFundingState(block.timestamp);
        _core.updatePrice();
        _;
        _core.updateFundingRate();
    }

    modifier onlyWhen(State allowedState) {
        require(_core.state == allowedState, "operation is disallowed");
        _;
    }

    modifier onlyNotWhen(State disallowedState) {
        require(_core.state != disallowedState, "operation is disallow");
        _;
    }

    function governor() public view returns (address) {
        return _governor;
    }

    function shareToken() public view returns (address) {
        return _shareToken;
    }

    function information()
        public
        view
        returns (
            string memory underlyingAsset,
            address collateral,
            address factory,
            address oracle,
            address operator,
            address vault,
            int256[8] memory coreParameter,
            int256[5] memory riskParameter
        )
    {
        underlyingAsset = IOracle(_core.oracle).underlyingAsset();
        collateral = IOracle(_core.oracle).collateral();
        factory = _core.factory;
        oracle = _core.oracle;
        operator = _core.operator;
        vault = _core.vault;
        coreParameter = [
            _core.initialMarginRate,
            _core.maintenanceMarginRate,
            _core.operatorFeeRate,
            _core.vaultFeeRate,
            _core.lpFeeRate,
            _core.referrerRebateRate,
            _core.liquidationPenaltyRate,
            _core.keeperGasReward
        ];
        riskParameter = [
            _core.halfSpreadRate.value,
            _core.beta1.value,
            _core.beta2.value,
            _core.fundingRateCoefficient.value,
            _core.targetLeverage.value
        ];
    }

    function state()
        public
        syncState
        returns (
            bool isEmergency,
            bool isCleared,
            int256 insuranceFund,
            int256 donatedInsuranceFund,
            int256 markPrice,
            int256 indexPrice
        )
    {
        isEmergency = _core.state == State.EMERGENCY;
        isCleared = _core.state == State.CLEARED;
        insuranceFund = _core.insuranceFund;
        donatedInsuranceFund = _core.donatedInsuranceFund;
        markPrice = _core.markPrice();
        indexPrice = _core.indexPrice();
    }

    function fundingState()
        public
        syncState
        returns (
            int256 unitAccumulativeFunding,
            int256 fundingRate,
            uint256 fundingTime
        )
    {
        unitAccumulativeFunding = _core.unitAccumulativeFunding;
        fundingRate = _core.fundingRate;
        fundingTime = _core.fundingTime;
    }

    function marginAccount(address trader)
        public
        view
        returns (
            int256 cashBalance,
            int256 positionAmount,
            int256 entryFunding
        )
    {
        cashBalance = _core.marginAccounts[trader].cashBalance;
        positionAmount = _core.marginAccounts[trader].positionAmount;
        entryFunding = _core.marginAccounts[trader].entryFunding;
    }

    function margin(address trader) public syncState returns (int256) {
        return _core.margin(trader);
    }

    function availableMargin(address trader) public syncState returns (int256) {
        return _core.availableMargin(trader);
    }

    function claimableFee(address claimer) public view returns (int256) {
        return _core.claimableFees[claimer];
    }

    function _initialize(
        address operator,
        address oracle,
        address governor_,
        address shareToken_,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) internal {
        _core.operator = operator;
        _core.factory = msg.sender;
        _core.vault = IFactory(_core.factory).vault();
        _core.vaultFeeRate = IFactory(_core.factory).vaultFeeRate();

        _core.oracle = oracle;
        _initializeCollateral(IOracle(oracle).collateral());
        _initializeParameters(coreParams, riskParams, minRiskParamValues, maxRiskParamValues);

        _governor = governor_;
        _shareToken = shareToken_;
    }

    function _initializeCollateral(address collateral) internal {
        require(collateral != address(0), "collateral is invalid");
        (uint8 decimals, bool ok) = collateral.retrieveDecimals();
        require(ok, "cannot read decimals");
        require(decimals <= MAX_COLLATERAL_DECIMALS, "decimals is out of range");

        _core.collateral = collateral;
        _core.scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));
        _core.isWrapped = collateral == IFactory(_core.factory).weth();
    }

    function _initializeParameters(
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) internal {
        _core.initialMarginRate = coreParams[0];
        _core.maintenanceMarginRate = coreParams[1];
        _core.operatorFeeRate = coreParams[2];
        _core.lpFeeRate = coreParams[3];
        _core.referrerRebateRate = coreParams[4];
        _core.liquidationPenaltyRate = coreParams[5];
        _core.keeperGasReward = coreParams[6];
        _core.validateCoreParameters();

        _core.halfSpreadRate.updateOption(
            riskParams[0],
            minRiskParamValues[0],
            maxRiskParamValues[0]
        );
        _core.beta1.updateOption(riskParams[1], minRiskParamValues[1], maxRiskParamValues[1]);
        _core.beta2.updateOption(riskParams[2], minRiskParamValues[2], maxRiskParamValues[2]);
        _core.fundingRateCoefficient.updateOption(
            riskParams[3],
            minRiskParamValues[3],
            maxRiskParamValues[3]
        );
        _core.targetLeverage.updateOption(
            riskParams[4],
            minRiskParamValues[4],
            maxRiskParamValues[4]
        );
        _core.validateRiskParameters();
    }

    function _enterEmergencyState() internal onlyWhen(State.NORMAL) {
        _core.updatePrice();
        _core.state = State.EMERGENCY;
        _core.freezeOraclePrice();
    }

    function _enterClearedState() internal onlyWhen(State.EMERGENCY) {
        _core.state = State.CLEARED;
    }

    function updateIndex()
        public
        returns (
            int256,
            int256,
            int256
        )
    {
        _core.updateFundingState(block.timestamp);
        _core.updatePrice();
        _core.updateFundingRate();
        return marginAccount(address(this));
    }

    bytes[50] private __gap;
}
