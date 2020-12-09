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

    event CreatePerpetual(
        address perpetual,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        address collateral,
        int256[7] coreParams,
        int256[5] riskParams
    );

    function createPerpetual(
        address oracle,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues,
        uint256 nonce
    ) external returns (address) {
        return
            _createPerpetualWith(
                latestVersion(),
                oracle,
                coreParams,
                riskParams,
                minRiskParamValues,
                maxRiskParamValues,
                nonce
            );
    }

    function createPerpetualWith(
        address implementation,
        address oracle,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues,
        uint256 nonce
    ) external returns (address) {
        return
            _createPerpetualWith(
                implementation,
                oracle,
                coreParams,
                riskParams,
                minRiskParamValues,
                maxRiskParamValues,
                nonce
            );
    }

    function _createPerpetualWith(
        address implementation,
        address oracle,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues,
        uint256 nonce
    ) internal returns (address) {
        require(isVersionValid(implementation), "invalid implementation");
        address governor = _createStaticProxy(_governorTemplate);
        address shareToken = _createStaticProxy(_shareTokenTemplate);
        address perpetual = _createPerpetualProxy(implementation, governor, nonce);
        shareToken.functionCall(
            abi.encodeWithSignature("initialize(address)", perpetual),
            "fail to init share token"
        );
        governor.functionCall(
            abi.encodeWithSignature("initialize(address,address)", shareToken, perpetual),
            "fail to init governor"
        );
        perpetual.functionCall(
            abi.encodeWithSignature(
                "initialize(address,address,address,address,int256[7],int256[5],int256[5],int256[5])",
                msg.sender,
                oracle,
                governor,
                shareToken,
                coreParams,
                riskParams,
                minRiskParamValues,
                maxRiskParamValues
            ),
            "fail to init perpetual"
        );
        _registerLiquidityPool(perpetual);
        emit CreatePerpetual(
            perpetual,
            governor,
            shareToken,
            msg.sender,
            oracle,
            IOracle(oracle).collateral(),
            coreParams,
            riskParams
        );
        return perpetual;
    }
}
