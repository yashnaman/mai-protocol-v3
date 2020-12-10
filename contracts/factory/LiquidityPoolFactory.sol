// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";

import "../interface/IOracle.sol";

import "./Creator.sol";
import "./Tracer.sol";
import "./Implementation.sol";
import "./Variables.sol";

contract LiquidityPoolFactory is Creator, Tracer, Implementation, Variables {
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
        address governor = _createStaticProxy(_governorTemplate);
        address shareToken = _createStaticProxy(_shareTokenTemplate);
        address liquidityPool = _createUpgradeableProxy(implementation, governor, nonce);
        shareToken.functionCall(
            abi.encodeWithSignature("initialize(address)", liquidityPool),
            "fail to init share token"
        );
        governor.functionCall(
            abi.encodeWithSignature("initialize(address,address)", shareToken, liquidityPool),
            "fail to init governor"
        );
        liquidityPool.functionCall(
            abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                msg.sender,
                collateral,
                governor,
                shareToken
            ),
            "fail to init perpetual"
        );
        _registerLiquidityPool(liquidityPool);
        emit CreateLiquidityPool(liquidityPool, governor, shareToken, msg.sender, collateral);
        return liquidityPool;
    }
}
