// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./interface/IFactory.sol";
import "./interface/IDecimals.sol";

import "./module/FundingModule.sol";
import "./module/OracleModule.sol";
import "./module/ParameterModule.sol";
import "./module/SettlementModule.sol";

import "./Type.sol";

contract Storage is Initializable {
    using SafeMathUpgradeable for uint256;
    using FundingModule for Core;
    using OracleModule for Core;
    using OracleModule for Market;
    using SettlementModule for Core;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    Core internal _core;
    address internal _governor;
    address internal _shareToken;

    modifier syncState() {
        uint256 currentTime = block.timestamp;
        _core.updateFundingState(currentTime);
        _core.updatePrice(currentTime);
        _;
        _core.updateFundingRate();
    }

    modifier onlyWhen(bytes32 marketID, MarketState allowedState) {
        require(_core.markets[marketID].state == allowedState, "operation is disallowed now");
        _;
    }

    modifier onlyNotWhen(bytes32 marketID, MarketState disallowedState) {
        require(_core.markets[marketID].state != disallowedState, "operation is disallow now");
        _;
    }

    event EnterEmergencyState();
    event EnterClearedState();

    function initialize(
        address collateral,
        address operator,
        address governor,
        address shareToken
    ) internal initializer {
        require(collateral != address(0), "collateral is invalid");
        require(governor != address(0), "governor is invalid");
        require(shareToken != address(0), "shareToken is invalid");

        uint8 decimals = IDecimals(collateral).decimals();
        require(decimals <= MAX_COLLATERAL_DECIMALS, "collateral decimals is out of range");
        _core.collateral = collateral;
        _core.scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));

        _core.factory = msg.sender;
        IFactory factory = IFactory(_core.factory);
        _core.isWrapped = (collateral == factory.weth());
        _core.vault = factory.vault();
        _core.vaultFeeRate = factory.vaultFeeRate();

        _core.operator = operator;
        _core.shareToken = shareToken;
    }

    function _enterEmergencyState(bytes32 marketID)
        internal
        onlyWhen(marketID, MarketState.NORMAL)
    {
        uint256 currentTime = block.timestamp;
        _core.updatePrice(currentTime);
        _core.markets[marketID].state = MarketState.EMERGENCY;
        _core.markets[marketID].freezeOraclePrice(currentTime);
        emit EnterEmergencyState();
    }

    function _enterClearedState(bytes32 marketID)
        internal
        onlyWhen(marketID, MarketState.EMERGENCY)
    {
        _core.markets[marketID].state = MarketState.CLEARED;
        emit EnterClearedState();
    }

    bytes[50] private __gap;
}
