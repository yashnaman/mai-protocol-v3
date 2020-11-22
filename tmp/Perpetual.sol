// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

import "./libraries/Error.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";
import "./libraries/OrderUtils.sol";
import "./libraries/SignatureValidator.sol";

import "./Type.sol";
import "./Context.sol";
import "./Collateral.sol";
import "./Trade.sol";
import "./State.sol";
import "./Settle.sol";
import "./AccessControl.sol";

import "./interface/IOracle.sol";
import "./interface/IShareToken.sol";

contract Perpetual is
    Context,
    Trade,
    Settle,
    AccessControl,
    Collateral,
    ReentrancyGuard
{
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using OrderUtils for Order;
    using SignatureValidator for Signature;

    event Deposit(address trader, int256 amount);
    event Withdraw(address trader, int256 amount);
    event Clear(address trader);
    event AddLiquidatity(address trader, int256 amount);
    event RemoveLiquidatity(address trader, int256 amount);
    event DonateInsuranceFund(address trader, int256 amount);
    event TradePosition(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline,
        int256 fee
    );
    event Liquidate1(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline,
        int256 fee
    );
    event Liquidate2(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    );
    event UpdateCoreSetting(bytes32 key, int256 value);
    event UpdateRiskSetting(
        bytes32 key,
        int256 value,
        int256 minValue,
        int256 maxValue
    );
    event AdjustRiskSetting(bytes32 key, int256 value);
    event ClaimFee(address claimer, int256 amount);

    function initialize(
        address operator,
        address oracle,
        address voter,
        address shareToken,
        int256[CORE_PARAMETER_COUNT] calldata coreParams,
        int256[RISK_PARAMETER_COUNT] calldata riskParams,
        int256[RISK_PARAMETER_COUNT] calldata minRiskParamValues,
        int256[RISK_PARAMETER_COUNT] calldata maxRiskParamValues
    ) external {
        _oracle = oracle;
        _factory = _msgSender();

        __CoreInitialize(operator, voter, shareToken, coreParams);
        __OracleInitialize(oracle);
        __FundingInitialize(riskParams, minRiskParamValues, maxRiskParamValues);
        __CollateralInitialize(IOracle(_oracle).collateral());
    }

    modifier updateFunding() {
        _updateFundingState();
        _;
        _updateFundingRate();
    }

    modifier authRequired(address trader, uint256 privilege) {
        require(
            trader == _msgSender() ||
                _isGranted(trader, _msgSender(), privilege),
            "auth required"
        );
        _;
    }

    modifier userTrace(address trader) {
        int256 preAmount = _marginAccounts[trader].positionAmount;
        _;
        int256 postAmount = _marginAccounts[trader].positionAmount;
        if (preAmount == 0 && postAmount != 0) {
            _registerTrader(trader);
            IFactory(_factory).activeProxy(trader, address(this));
        } else if (preAmount != 0 && postAmount == 0) {
            _deregisterTrader(trader);
            IFactory(_factory).deactiveProxy(trader, address(this));
        }
    }

    // admin
    // core settings -- can only be updated through voting
    function updateCoreParameter(bytes32 key, int256 newValue)
        external
        voteOnly
    {
        _updateCoreParameter(key, newValue);
        emit UpdateCoreSetting(key, newValue);
    }

    function updateRiskParameter(
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) external voteOnly {
        _updateRiskParameter(key, newValue, minValue, maxValue);
        emit UpdateRiskSetting(key, newValue, minValue, maxValue);
    }

    function adjustRiskParameter(bytes32 key, int256 newValue)
        external
        operatorOnly
    {
        _adjustRiskParameter(key, newValue);
        emit AdjustRiskSetting(key, newValue);
    }

    // reader
    function claimableFee(address claimer) external view returns (int256) {
        return _claimableFee[claimer];
    }

    function marginAccount(address trader)
        external
        view
        returns (
            int256 positionAmount,
            int256 cashBalance,
            int256 entryFundingLoss
        )
    {
        positionAmount = _marginAccounts[trader].positionAmount;
        cashBalance = _marginAccounts[trader].cashBalance;
        entryFundingLoss = _marginAccounts[trader].entryFundingLoss;
    }

    function margin(address trader) external updateFunding returns (int256) {
        return _margin(trader);
    }

    function availableMargin(address trader)
        external
        updateFunding
        returns (int256)
    {
        return _availableMargin(trader);
    }

    function withdrawableMargin(address trader)
        external
        updateFunding
        returns (int256 withdrawable)
    {
        if (_isNormal()) {
            withdrawable = _availableMargin(trader);
        } else {
            withdrawable = _settle(trader);
        }
        return withdrawable > 0 ? withdrawable : 0;
    }

    function info()
        external
        view
        returns (
            string memory underlyingAsset,
            address collateral,
            address factory,
            address oracle,
            address operator,
            address voter,
            address shareToken,
            address vault
        )
    {
        underlyingAsset = IOracle(_oracle).underlyingAsset();
        collateral = IOracle(_oracle).collateral();
        factory = _factory;
        oracle = _oracle;
        operator = _operator;
        voter = _voter;
        shareToken = _shareToken;
        vault = _vault;
    }

    function parameters()
        external
        view
        returns (int256[8] memory coreParameter, int256[5] memory riskParameter)
    {
        coreParameter = [
            _coreParameter.initialMarginRate,
            _coreParameter.maintenanceMarginRate,
            _coreParameter.operatorFeeRate,
            _coreParameter.vaultFeeRate,
            _coreParameter.lpFeeRate,
            _coreParameter.referrerRebateRate,
            _coreParameter.liquidationPenaltyRate,
            _coreParameter.keeperGasReward
        ];
        riskParameter = [
            _riskParameter.halfSpreadRate.value,
            _riskParameter.beta1.value,
            _riskParameter.beta2.value,
            _riskParameter.fundingRateCoefficient.value,
            _riskParameter.targetLeverage.value
        ];
    }

    function state()
        external
        returns (
            bool isEmergency,
            bool isShuttingdown,
            int256 insuranceFund1,
            int256 insuranceFund2,
            int256 markPrice,
            int256 indexPrice
        )
    {
        isEmergency = _emergency;
        isShuttingdown = _shuttingdown;
        insuranceFund1 = _insuranceFund1;
        insuranceFund2 = _insuranceFund2;
        markPrice = _markPrice();
        indexPrice = _indexPrice();
    }

    function fundingState()
        external
        view
        returns (
            int256 unitAccumulatedFundingLoss,
            int256 fundingRate,
            uint256 fundingTime
        )
    {
        unitAccumulatedFundingLoss = _fundingState.unitAccumulatedFundingLoss;
        fundingRate = _fundingState.fundingRate;
        fundingTime = _fundingState.fundingTime;
    }

    // actions
    function shutdown() external whenNormal {
        require(
            _now().sub(_indexPriceData().timestamp) > 24 * 3600,
            "index price timeout"
        );
        _enterEmergencyState();
    }

    function claimFee(address claimer, int256 amount) external nonReentrant {
        require(amount != 0, "zero amount");
        _claimFee(claimer, amount);
        _transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }

    function deposit(address trader, int256 amount)
        external
        authRequired(trader, Constant.PRIVILEGE_DEPOSTI)
        whenNormal
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _transferFromUser(trader, amount);
        _updateCashBalance(trader, amount);
        emit Withdraw(trader, amount);
    }

    function donateInsuranceFund(int256 amount) internal {
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _insuranceFund2 = _insuranceFund2.add(amount);
        _transferFromUser(_msgSender(), amount);
        emit DonateInsuranceFund(_msgSender(), amount);
    }

    function withdraw(address trader, int256 amount)
        external
        updateFunding
        authRequired(trader, Constant.PRIVILEGE_WITHDRAW)
        whenNormal
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(amount > 0, Error.INVALID_COLLATERAL_AMOUNT);
        _updateCashBalance(trader, amount.neg());
        _isInitialMarginSafe(trader);
        _transferFromUser(trader, amount);
    }

    function numTraderToClear() external view whenEmergency returns (uint256) {
        return _numTraderToClear();
    }

    function listTraderToClear(uint256 begin, uint256 end)
        external
        view
        whenEmergency
        returns (address[] memory)
    {
        return _listTraderToClear(begin, end);
    }

    function clear(address trader) external whenEmergency {
        _clear(trader);
        emit Clear(trader);
    }

    function settle(address trader)
        external
        authRequired(trader, Constant.PRIVILEGE_WITHDRAW)
        whenShuttingDown
        nonReentrant
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);

        int256 withdrawable = _settle(trader);
        _updateCashBalance(trader, withdrawable.neg());
        _transferFromUser(trader, withdrawable);
        emit Withdraw(trader, withdrawable);
    }

    function addLiquidatity(int256 marginToAdd)
        external
        updateFunding
        whenNormal
        nonReentrant
    {
        require(marginToAdd > 0, Error.INVALID_COLLATERAL_AMOUNT);

        int256 shareToMint = AMMTrade.addLiquidity(
            _riskParameter,
            _fundingState,
            _marginAccounts[_self()],
            _indexPrice(),
            IShareToken(_shareToken).totalSupply().toInt256(),
            marginToAdd
        );
        _transferFromUser(_msgSender(), marginToAdd);
        _updateCashBalance(_self(), marginToAdd);
        IShareToken(_shareToken).mint(
            _msgSender(),
            shareToMint.toUint256(),
            _insuranceFund1.toUint256()
        );

        emit AddLiquidatity(_msgSender(), marginToAdd);
    }

    function removeLiquidatity(int256 shareToRemove)
        external
        updateFunding
        whenNormal
        nonReentrant
    {
        require(shareToRemove > 0, Error.INVALID_COLLATERAL_AMOUNT);

        int256 cashToReturn = AMMTrade.removeLiquidity(
            _riskParameter,
            _fundingState,
            _marginAccounts[_self()],
            _indexPrice(),
            IShareToken(_shareToken).totalSupply().toInt256(),
            shareToRemove
        );

        _updateCashBalance(_self(), cashToReturn.neg());
        _transferToUser(payable(_msgSender()), cashToReturn);
        emit RemoveLiquidatity(_msgSender(), shareToRemove);
    }

    function trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    ) external authRequired(trader, Constant.PRIVILEGE_TRADE) {
        _trade(trader, amount, priceLimit, deadline, referrer);
    }

    function brokerTrade(Order calldata order, int256 amount)
        external
        userTrace(order.trader)
        updateFunding
        whenNormal
    {
        address signer = order.signature.getSigner(order.orderHash());
        require(
            signer == order.trader ||
                _isGranted(order.trader, signer, Constant.PRIVILEGE_TRADE),
            ""
        );
        (bool valid, string memory reason) = order.validateOrderFields(
            _marginAccounts[order.trader],
            amount
        );
        require(valid, reason);
        _trade(
            order.trader,
            amount,
            order.priceLimit,
            order.deadline,
            order.referrer
        );
    }

    function _trade(
        address trader,
        int256 amount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    ) internal userTrace(trader) updateFunding whenNormal {
        require(amount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);
        Receipt memory receipt = _trade(trader, amount, priceLimit, referrer);
        emit TradePosition(
            trader,
            amount,
            priceLimit,
            deadline,
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee).add(
                receipt.referrerFee
            )
        );
    }

    function liquidate(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external userTrace(trader) updateFunding whenNormal {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        Receipt memory receipt = _liquidate1(
            trader,
            positionAmount,
            priceLimit
        );
        emit Liquidate1(
            trader,
            positionAmount,
            priceLimit,
            deadline,
            receipt.lpFee.add(receipt.vaultFee).add(receipt.operatorFee)
        );
    }

    function liquidate2(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    )
        external
        userTrace(_msgSender())
        userTrace(trader)
        updateFunding
        whenNormal
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        _liquidate2(_msgSender(), trader, positionAmount, priceLimit);
        emit Liquidate2(trader, positionAmount, priceLimit, deadline);
    }
}
