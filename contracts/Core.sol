// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Context.sol";
import "./Type.sol";

interface IFactory {
    function vault() external view returns (address);
    function vaultFeeRate() external view returns (int256);
}

contract Core is Context {

    int256 constant private BASIC_PARAMETER_LENGTH = 7;

    string internal _symbol;
    address internal _factory;
    address internal _operator;
    address internal _voter;

    int256 internal _reservedMargin;
    int256 internal _initialMarginRate;
    int256 internal _maintenanceMarginRate;
    int256 internal _operatorFeeRate;
    int256 internal _liquidityProviderFeeRate;
    int256 internal _liquidationPenaltyRate;
    int256 internal _liquidationGasReward;

    function __CoreInitialize(
        string calldata symbol,
        address operator,
        address voter,
        int256[BASIC_PARAMETER_LENGTH] calldata argValues
    ) internal {
        require(operator != address(0), "invalid operator");

        _symbol = symbol;
        _factory = _msgSender();
        _operator = operator;
        _voter = voter;

        _reservedMargin = argValues[0];
        _initialMarginRate = argValues[1];
        _maintenanceMarginRate = argValues[2];
        _operatorFeeRate = argValues[3];
        _liquidityProviderFeeRate = argValues[4];
        _liquidationPenaltyRate = argValues[5];
        _liquidationGasReward = argValues[6];
    }

    modifier onlyVoter() {
        require(_msgSender() == _voter, "");
        _;
    }

    modifier onlyOperator() {
        require(_msgSender() == _operator, "");
        _;
    }

    function _vault() internal view returns (address) {
        return IFactory(_factory).vault();
    }

    function _vaultFeeRate() internal view returns (int256) {
        return IFactory(_factory).vaultFeeRate();
    }

    function _updateSetting(bytes32 key, int256 newValue) internal {
        if (key == "reserveMargin") {
            _reservedMargin = newValue;
        } else if (key == "initialMarginRate") {
            _initialMarginRate = newValue;
        } else if (key == "maintenanceMarginRate") {
            _maintenanceMarginRate = newValue;
        } else if (key == "operatorFeeRate") {
            _operatorFeeRate = newValue;
        } else if (key == "liquidityProviderFeeRate") {
            _liquidityProviderFeeRate = newValue;
        } else if (key == "liquidationPenaltyRate") {
            _liquidityProviderFeeRate = newValue;
        } else if (key == "liquidationGasReward") {
            _liquidationGasReward = newValue;
        } else {
            revert("key not found");
        }
    }

    bytes32[50] private __gap;
}