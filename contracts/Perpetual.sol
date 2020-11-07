// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./libraries/Error.sol";
import "./libraries/SafeMathExt.sol";
import "./libraries/Utils.sol";

import "./Type.sol";
import "./Core.sol";
import "./Context.sol";
import "./Action.sol";
import "./State.sol";

import "./module/MarginModule.sol";
import "./module/AccessControlModule.sol";

contract Perpetual is Core, Action, Context {

    using MarginModule for MarginAccount;
    using AccessControlModule for AccessControl;

    event Deposit(address trader, int256 collateralAmount);
    event Withdraw(address trader, int256 collateralAmount);
    event Trade(address trader, int256 positionAmount, int256 priceLimit, uint256 deadline);
    event Liquidate1(address trader, int256 positionAmount, int256 priceLimit, uint256 deadline);
    event Liquidate2(address trader, int256 positionAmount, int256 priceLimit, uint256 deadline);

    function initialize(
        string calldata symbol,
        address oracle,
        address operator,
        int256[14] calldata arguments
    ) external {
        _symbol = symbol;
        _oracle = oracle;
        _factory = _msgSender();
        _operator = operator;

        _settings.reservedMargin = arguments[0];
        _settings.initialMarginRate = arguments[1];
        _settings.maintenanceMarginRate = arguments[2];
        _settings.vaultFeeRate = arguments[3];
        _settings.operatorFeeRate = arguments[4];
        _settings.liquidityProviderFeeRate = arguments[5];
        _settings.liquidationPenaltyRate1 = arguments[6];
        _settings.liquidationPenaltyRate2 = arguments[7];
        _settings.liquidationGasReserve = arguments[8];
        _settings.halfSpreadRate = arguments[9];
        _settings.beta1 = arguments[10];
        _settings.beta2 = arguments[11];
        _settings.baseFundingRate = arguments[12];
        _settings.targetLeverage = arguments[13];
    }

    modifier updateFunding() {
        _tryUpdateFundingState();
        _;
        _tryUpdateFundingRate();
    }

    modifier authRequired(address trader, uint256 privilege) {
        require(
            trader == _msgSender() || _accessControls[trader][_msgSender()].isGranted(privilege),
            "auth required"
        );
        _;
    }

    // atribute
    function initialMargin(address trader) public view returns (int256) {
        ( int256 markPrice, ) = _markPrice();
        return _marginAccounts[trader].initialMargin(_settings, markPrice);
    }

    function maintenanceMargin(address trader) public view returns (int256) {
        ( int256 markPrice, ) = _markPrice();
        return _marginAccounts[trader].maintenanceMargin(_settings, markPrice);
    }

    function availableMargin(address trader) public view returns (int256) {
        ( int256 markPrice, ) = _markPrice();
        return _marginAccounts[trader].availableMargin(
            _settings,
            markPrice,
            _state.unitAccumulatedFundingLoss
        );
    }

    function withdrawableMargin(address trader) public view returns (int256) {
        ( int256 markPrice, ) = _markPrice();
        return _marginAccounts[trader].withdrawableMargin(
            _settings,
            markPrice,
            _state.unitAccumulatedFundingLoss
        );
    }

    // trade
    function deposit(
        address trader,
        int256 collateralAmount
    ) external authRequired(trader, Constant.PRIVILEGE_DEPOSTI) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _deposit(trader, collateralAmount);

        emit Deposit(trader, collateralAmount);
    }

    function withdraw(
        address trader,
        int256 collateralAmount
    ) external updateFunding authRequired(trader, Constant.PRIVILEGE_DEPOSTI) {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, Error.INVALID_COLLATERAL_AMOUNT);

        _withdraw(trader, collateralAmount);

        emit Withdraw(trader, collateralAmount);
    }

    function trade(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding authRequired(trader, Constant.PRIVILEGE_TRADE) {
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        _trade(trader, positionAmount, priceLimit);

        emit Trade(trader, positionAmount, priceLimit, deadline);
    }

    function liquidate(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        _liquidate(trader, positionAmount, priceLimit);

        emit Liquidate1(trader, positionAmount, priceLimit, deadline);
    }

    function liquidate2(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding {
        require(trader != address(0), Error.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, Error.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, Error.INVALID_TRADING_PRICE);
        require(deadline >= _now(), Error.EXCEED_DEADLINE);

        _liquidate2(_msgSender(), trader, positionAmount, priceLimit);

        emit Liquidate2(trader, positionAmount, priceLimit, deadline);
    }

}