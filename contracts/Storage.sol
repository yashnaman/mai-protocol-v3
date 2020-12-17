// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./interface/IAccessController.sol";

import "./module/FundingModule.sol";
import "./module/OracleModule.sol";
import "./module/ParameterModule.sol";
import "./module/SettlementModule.sol";

import "./Type.sol";

contract Storage {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using FundingModule for Core;
    using OracleModule for Core;
    using OracleModule for Perpetual;
    using SettlementModule for Core;

    Core internal _core;
    address internal _governor;
    address internal _shareToken;

    modifier onlyExistedPerpetual(uint256 perpetualIndex) {
        require(perpetualIndex < _core.perpetuals.length, "perpetual not exist");
        _;
    }

    modifier syncState() {
        uint256 currentTime = block.timestamp;
        _core.updateFundingState(currentTime);
        _core.updatePrice(currentTime);
        _;
        _core.updateFundingRate();
    }

    modifier onlyWhen(uint256 perpetualIndex, PerpetualState allowedState) {
        require(
            _core.perpetuals[perpetualIndex].state == allowedState,
            "operation is disallowed now"
        );
        _;
    }

    modifier onlyNotWhen(uint256 perpetualIndex, PerpetualState disallowedState) {
        require(
            _core.perpetuals[perpetualIndex].state != disallowedState,
            "operation is disallow now"
        );
        _;
    }

    modifier onlyAuthorized(address trader, uint256 privilege) {
        require(
            trader == msg.sender ||
                IAccessController(_core.accessController).isGranted(trader, msg.sender, privilege),
            "unauthorized operation"
        );
        _;
    }

    bytes[50] private __gap;
}
