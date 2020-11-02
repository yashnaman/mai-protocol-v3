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