// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";

import "../interface/IOracle.sol";

import "./Proxy.sol";
import "./Tracer.sol";
import "./Implementation.sol";
import "./Variables.sol";

import "hardhat/console.sol";

contract PoolCreator is Creator, Tracer, Implementation, Variables {
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

    event CreateSharedLiquidityPool(
        address sharedLiquidityPool,
        address governor,
        address shareToken,
        address operator,
        address collateral
    );

    function createSharedLiquidityPool(address collateral, uint256 nonce)
        external
        returns (address)
    {
        return _createSharedLiquidityPoolWith(latestVersion(), collateral, nonce);
    }

    function createSharedLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 nonce
    ) external returns (address) {
        return _createSharedLiquidityPoolWith(implementation, collateral, nonce);
    }

    function _createSharedLiquidityPoolWith(
        address implementation,
        address collateral,
        uint256 nonce
    ) internal returns (address) {
        require(isVersionValid(implementation), "invalid implementation");
        address governor = _createStaticProxy(_governorTemplate);
        address shareToken = _createStaticProxy(_shareTokenTemplate);
        address sharedLiquidityPool = _createUpgradeableProxy(implementation, governor, nonce);
        shareToken.functionCall(
            abi.encodeWithSignature(
                "initialize(string,string,address)",
                "MCDEX Share Token",
                "STK",
                sharedLiquidityPool
            ),
            "fail to init share token"
        );
        governor.functionCall(
            abi.encodeWithSignature("initialize(address,address)", shareToken, sharedLiquidityPool),
            "fail to init governor"
        );
        sharedLiquidityPool.functionCall(
            abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                msg.sender,
                collateral,
                governor,
                shareToken
            ),
            "fail to init sharedLiquidityPool"
        );
        _registerSharedLiquidityPool(sharedLiquidityPool);
        emit CreateSharedLiquidityPool(
            sharedLiquidityPool,
            governor,
            shareToken,
            msg.sender,
            collateral
        );
        return sharedLiquidityPool;
    }
}
