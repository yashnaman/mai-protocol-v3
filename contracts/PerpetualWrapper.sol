// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./Type.sol";
import "./lib/LibError.sol";

import "./implementation/MarginAccountImp.sol";
import "./implementation/TradeImp.sol";
import "./implementation/AMMImp.sol";
import "./implementation/AuthenticationImpl.sol";

contract PerpetualWrapper {

    using AuthenticationImpl for Perpetual;
    using MarginAccountImp for Perpetual;
    using TradeImp for Perpetual;
    using AMMImp for Perpetual;

    Perpetual internal _perpetual;

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

    function deposit(address trader, int256 collateralAmount) external {
        require(collateralAmount > 0, LibError.INVALID_COLLATERAL_AMOUNT);
        _perpetual.deposit(_perpetual.traderAccounts[trader], collateralAmount);
    }

    function withdraw(address trader, int256 collateralAmount) external {
        require(collateralAmount > 0, LibError.INVALID_COLLATERAL_AMOUNT);
        _perpetual.deposit(_perpetual.traderAccounts[trader], collateralAmount);
    }

    function trade(int256 positionAmount, int256 priceLimit) external {
        Context memory context;
        _perpetual.updateFundingRate(context);
        _perpetual.trade(context, positionAmount, priceLimit);
        // _perpetual.commit(context);
    }

    function liquidate(address trader, int256 positionAmount, int256 priceLimit) external {
        Context memory context;
        _perpetual.updateFundingRate(context);
        _perpetual.liquidate(context, positionAmount, priceLimit);
        // _perpetual.commit(context);
    }

    function liquidate2(address trader, int256 positionAmount, int256 priceLimit) external {
        Context memory context;
        _perpetual.updateFundingRate(context);
        _perpetual.liquidate2(context, positionAmount, priceLimit);
        // _perpetual.commit(context);
    }
}