// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";

import "../interface/IGovernor.sol";
import "../interface/ILiquidityPool.sol";
import "../interface/IShareToken.sol";

import "./Proxy.sol";
import "./Tracer.sol";
import "./Implementation.sol";
import "./Variables.sol";
import "./AccessControl.sol";

import "hardhat/console.sol";

contract PoolCreator is Creator, Tracer, Implementation, Variables, AccessControl {
    using Address for address;

    address internal _governorTemplate;
    address internal _shareTokenTemplate;

    constructor(
        address governorTemplate,
        address shareTokenTemplate,
        address wethToken,
        address globalVault,
        int256 globalVaultFeeRate
    ) Variables(wethToken, globalVault, globalVaultFeeRate) Implementation() {
        require(governorTemplate.isContract(), "governor template must be contract");
        require(shareTokenTemplate.isContract(), "share token template must be contract");
        _governorTemplate = governorTemplate;
        _shareTokenTemplate = shareTokenTemplate;
    }

    event CreateLiquidityPool(
        address liquidityPool,
        address governor,
        address shareToken,
        address operator,
        address collateral
    );

    function createLiquidityPool(address collateral, uint256 nonce) external returns (address) {
        return _createLiquidityPoolWith(latestVersion(), collateral, nonce);
    }

    function createLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 nonce
    ) external returns (address) {
        return _createLiquidityPoolWith(implementation, collateral, nonce);
    }

    function _createLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 nonce
    ) internal returns (address) {
        require(isVersionValid(implementation), "invalid implementation");
        address governor = _createClone(_governorTemplate);
        address shareToken = _createClone(_shareTokenTemplate);
        address liquidityPool = _createUpgradeableProxy(implementation, governor, nonce);
        // initialize
        IShareToken(shareToken).initialize("MCDEX Share Token", "STK", liquidityPool);
        IGovernor(governor).initialize(shareToken, liquidityPool);
        ILiquidityPool(liquidityPool).initialize(msg.sender, collateral, governor, shareToken);
        // register
        _registerLiquidityPool(liquidityPool);
        emit CreateLiquidityPool(liquidityPool, governor, shareToken, msg.sender, collateral);
        return liquidityPool;
    }
}
