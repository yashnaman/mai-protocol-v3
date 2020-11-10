// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./Type.sol";

contract Core {
    string internal _symbol;
    address internal _oracle;
    address internal _factory;
    address internal _operator;

    bool internal _emergency;
    bool internal _shutdown;

    int256 internal _insuranceFund;
    int256 internal _totalPositionAmount;

    OraclePrice internal _indexOracleData;
    OraclePrice internal _marketOracleData;

    Settings internal _settings;
    FundingState internal _fundingState;

    mapping(address => int256) internal _entryInsuranceFund;
    mapping(address => MarginAccount) internal _marginAccounts;
    mapping(address => mapping(address => AccessControl)) internal _accessControls;

    bytes32[50] __gap;
}