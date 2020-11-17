// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./libraries/Error.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./Type.sol";
import "./Context.sol";
import "./Collateral.sol";
import "./Trade.sol";
import "./State.sol";
import "./Settle.sol";
import "./AccessControl.sol";

contract Perpetual is Context, Trade, Settle, AccessControl, Collateral {
    event Deposit(address trader, int256 collateralAmount);
    event Withdraw(address trader, int256 collateralAmount);
    event AddLiquidatity(address trader, int256 collateralAmount);
    event RemoveLiquidatity(address trader, int256 collateralAmount);

    event TradePosition(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    );
    event Liquidate1(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
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

    // function initialize(
    //     string calldata symbol,
    //     address oracle,
    //     address operator,
    //     int256[14] calldata arguments,
    //     int256[14] calldata argumentsMinValue,
    //     int256[14] calldata argumentsMaxValue
    // ) external {
    //     _symbol = symbol;
    //     _oracle = oracle;
    //     _factory = _msgSender();
    //     _operator = operator;

    //     _settings.reservedMargin = arguments[0];
    //     _settings.initialMarginRate = arguments[1];
    //     _settings.maintenanceMarginRate = arguments[2];
    //     _settings.vaultFeeRate = arguments[3];
    //     _settings.operatorFeeRate = arguments[4];
    //     _settings.liquidityProviderFeeRate = arguments[5];
    //     _settings.liquidationPenaltyRate1 = arguments[6];
    //     _settings.liquidationPenaltyRate2 = arguments[7];
    //     _settings.liquidationGasReserve = arguments[8];
    //     _settings.halfSpreadRate = arguments[9];
    //     _settings.beta1 = arguments[10];
    //     _settings.beta2 = arguments[11];
    //     _settings.baseFundingRate = arguments[12];
    //     _settings.targetLeverage = arguments[13];
    // }

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
            _registerUser(trader);
        } else if (preAmount != 0 && postAmount == 0) {
            _deregisterUser(trader);
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

    //
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

    function claimableFee(address claimer) external view returns (int256) {
        return _claimableFee[claimer];
    }

    function claimFee(address claimer, int256 amount) external {
        _claimFee(claimer, amount);
        emit ClaimFee(claimer, amount);
    }

    // reade
    function marginAccount(address trader)
        external
        returns (
            int256 margin,
            int256 positionAmount,
            int256 availableMargin
        )
    {
        margin = _margin(trader);
        positionAmount = _marginAccounts[trader].positionAmount;
        availableMargin = _availableMargin(trader);
    }

    function ammState() external view returns (int256 unitAccFundingLoss) {
        return _fundingState.unitAccFundingLoss;
    }

    // trade
    function deposit(address trader, int256 collateralAmount)
        external
        authRequired(trader, Constant.PRIVILEGE_DEPOSTI)
        whenNormal
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _transferFromUser(trader, collateralAmount);
        _deposit(trader, collateralAmount);
        emit Deposit(trader, collateralAmount);
    }

    function withdraw(address trader, int256 collateralAmount)
        external
        updateFunding
        authRequired(trader, Constant.PRIVILEGE_WITHDRAW)
        whenNormal
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _withdraw(trader, collateralAmount);
        _transferFromUser(trader, collateralAmount);
        emit Withdraw(trader, collateralAmount);
    }

    function settle(address trader, int256 collateralAmount)
        external
        updateFunding
        authRequired(trader, Constant.PRIVILEGE_WITHDRAW)
    {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _withdraw(trader, collateralAmount);
        _transferFromUser(trader, collateralAmount);
        emit Withdraw(trader, collateralAmount);
    }

    function addLiquidatity(address trader, int256 collateralAmount) public {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _deposit(address(this), collateralAmount);
        _transferFromUser(trader, collateralAmount);
        emit AddLiquidatity(trader, collateralAmount);
    }

    function removeLiquidatity(address trader, int256 collateralAmount) public {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _removeLiquidity(trader, collateralAmount);
        _transferFromUser(trader, collateralAmount);
        emit RemoveLiquidatity(trader, collateralAmount);
    }

    function trade(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline,
        address referrer
    )
        external
        userTrace(trader)
        updateFunding
        whenNormal
        authRequired(trader, Constant.PRIVILEGE_TRADE)
    {
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        _trade(trader, positionAmount, priceLimit, referrer);
        emit TradePosition(trader, positionAmount, priceLimit, deadline);
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

        _liquidate1(trader, positionAmount, priceLimit);
        emit Liquidate1(trader, positionAmount, priceLimit, deadline);
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
