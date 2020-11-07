// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./Type.sol";
import "./lib/LibError.sol";

import "./implementation/AMMImp.sol";
import "./implementation/ContextImp.sol";
import "./implementation/MarginAccountImp.sol";
import "./implementation/TradeImp.sol";

import "./AccessControl.sol";
import "./CallContext.sol";

contract PerpetualWrapper is
    CallContext,
    AccessControl {

    using AMMImp for Perpetual;
    using ContextImp for Perpetual;
    using MarginAccountImp for Perpetual;
    using TradeImp for Perpetual;

    Perpetual internal _perpetual;

    event Deposit(address trader, int256 collateralAmount);
    event Withdraw(address trader, int256 collateralAmount);

    function initialize(
        string calldata symbol,
        address oracle,
        address operator,
        address vault,
        int256[14] calldata arguments
    ) external {
        _perpetual.symbol = symbol;
        _perpetual.oracle = oracle;
        _perpetual.operator = operator;
        _perpetual.vault = vault;
        _perpetual.parent = msg.sender;

        _perpetual.settings.reservedMargin = arguments[0];
        _perpetual.settings.initialMarginRate = arguments[1];
        _perpetual.settings.maintenanceMarginRate = arguments[2];
        _perpetual.settings.vaultFeeRate = arguments[3];
        _perpetual.settings.operatorFeeRate = arguments[4];
        _perpetual.settings.liquidityProviderFeeRate = arguments[5];
        _perpetual.settings.liquidationPenaltyRate1 = arguments[6];
        _perpetual.settings.liquidationPenaltyRate2 = arguments[7];
        _perpetual.settings.liquidationGasReserve = arguments[8];
        _perpetual.settings.halfSpreadRate = arguments[9];
        _perpetual.settings.beta1 = arguments[10];
        _perpetual.settings.beta2 = arguments[11];
        _perpetual.settings.baseFundingRate = arguments[12];
        _perpetual.settings.targetLeverage = arguments[13];
    }

    modifier updateFunding() {
        // update acc funding
        _;
        // update funding rate
    }

    modifier authRequired(address trader, uint256 privilege) {
        require(trader == msg.sender || _hasPrivilege(trader, msg.sender, privilege), "auth required");
        _;
    }

    // privilege
    function grantPrivilege(address accessor, uint256 privilege) public {
        _grantPrivilege(msg.sender, accessor, privilege);
    }

    function revokePrivilege(address accessor, uint256 privilege) public {
        _revokePrivilege(msg.sender, accessor, privilege);
    }

    function hasPrivilege(address owner, address accessor, uint256 privilege) public view returns (bool) {
        return _hasPrivilege(msg.sender, accessor, privilege);
    }

    // atribute
    function initialMargin(address trader) public view returns (int256) {
        return _perpetual.initialMargin(_perpetual.traderAccounts[trader]);
    }

    function maintenanceMargin(address trader) public view returns (int256) {
        return _perpetual.maintenanceMargin(_perpetual.traderAccounts[trader]);
    }

    function availableMargin(address trader) public view returns (int256) {
        return _perpetual.availableMargin(_perpetual.traderAccounts[trader]);
    }

    function withdrawableMargin(address trader) public view returns (int256) {
        return _perpetual.withdrawableMargin(_perpetual.traderAccounts[trader]);
    }

    // trade
    function deposit(
        address trader,
        int256 collateralAmount
    ) external authRequired(trader, _PRIVILEGE_DEPOSTI) {
        require(trader != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, LibError.INVALID_COLLATERAL_AMOUNT);

        _perpetual.increaseCashBalance(
            _perpetual.traderAccounts[trader], 
            collateralAmount
        );

        emit Deposit(trader, collateralAmount);
    }

    function withdraw(
        address trader,
        int256 collateralAmount
    ) external updateFunding authRequired(trader, _PRIVILEGE_DEPOSTI) {
        require(trader != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(collateralAmount > 0, LibError.INVALID_COLLATERAL_AMOUNT);

        _perpetual.decreaseCashBalance(
            _perpetual.traderAccounts[trader], 
            collateralAmount
        );
        _perpetual.isInitialMarginSafe(_perpetual.traderAccounts[trader]);

        emit Withdraw(trader, collateralAmount);
    }

    function trade(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding authRequired(trader, _PRIVILEGE_TRADE) {
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, LibError.INVALID_TRADING_PRICE);
        require(deadline >= _now(), LibError.EXCEED_DEADLINE);

        Context memory context = _perpetual.makeContext(trader, address(this));
        _perpetual.trade(context, positionAmount, priceLimit);
        _perpetual.commit(context);
    }

    function liquidate(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding {
        require(trader != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, LibError.INVALID_TRADING_PRICE);
        require(deadline >= _now(), LibError.EXCEED_DEADLINE);

        require(trader != address(0), LibError.INVALID_TRADER_ADDRESS);

        Context memory context = _perpetual.makeContext(msg.sender, trader);
        _perpetual.liquidate(context, positionAmount, priceLimit);
        _perpetual.commit(context);
    }

    function liquidate2(
        address trader,
        int256 positionAmount,
        int256 priceLimit,
        uint256 deadline
    ) external updateFunding {
        require(trader != address(0), LibError.INVALID_TRADER_ADDRESS);
        require(positionAmount > 0, LibError.INVALID_POSITION_AMOUNT);
        require(priceLimit >= 0, LibError.INVALID_TRADING_PRICE);
        require(deadline >= _now(), LibError.EXCEED_DEADLINE);

        Context memory context = _perpetual.makeContext(msg.sender, trader);
        _perpetual.liquidate2(context, positionAmount, priceLimit);
        _perpetual.commit(context);
    }
}