// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./libraries/Validator.sol";

import "./Context.sol";
import "./Type.sol";

import "./interface/IFactory.sol";

contract Core is Context {
    using Validator for CoreParameter;

    int256 internal constant CORE_PARAMETER_COUNT = 7;

    address internal _factory;
    address internal _operator;
    address internal _voter;
    address internal _vault;
    address internal _shareToken;

    CoreParameter internal _coreParameter;

    function __CoreInitialize(
        address operator,
        address voter,
        address shareToken,
        int256[CORE_PARAMETER_COUNT] calldata params
    ) internal {
        require(operator != address(0), "invalid operator");

        _operator = operator;
        _voter = voter;
        _factory = _msgSender();
        _shareToken = shareToken;

        _vault = IFactory(_factory).vault();
        _coreParameter.vaultFeeRate = IFactory(_factory).vaultFeeRate();

        _coreParameter.initialMarginRate = params[0];
        _coreParameter.maintenanceMarginRate = params[1];
        _coreParameter.operatorFeeRate = params[2];
        _coreParameter.lpFeeRate = params[3];
        _coreParameter.referrerRebateRate = params[4];
        _coreParameter.liquidationPenaltyRate = params[5];
        _coreParameter.keeperGasReward = params[6];

        _coreParameter.validate();
    }

    modifier voteOnly() {
        require(_msgSender() == _voter, "");
        _;
    }

    modifier operatorOnly() {
        require(_msgSender() == _operator, "");
        _;
    }

    function _updateCoreParameter(bytes32 key, int256 newValue) internal {
        if (key == "initialMarginRate") {
            _coreParameter.initialMarginRate = newValue;
        } else if (key == "maintenanceMarginRate") {
            _coreParameter.maintenanceMarginRate = newValue;
        } else if (key == "operatorFeeRate") {
            _coreParameter.operatorFeeRate = newValue;
        } else if (key == "lpFeeRate") {
            _coreParameter.lpFeeRate = newValue;
        } else if (key == "liquidationPenaltyRate") {
            _coreParameter.lpFeeRate = newValue;
        } else if (key == "keeperGasReward") {
            _coreParameter.keeperGasReward = newValue;
        } else {
            revert("key not found");
        }
        _coreParameter.validate();
    }

    bytes32[50] private __gap;
}
