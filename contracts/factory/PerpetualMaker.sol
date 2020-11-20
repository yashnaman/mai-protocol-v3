// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./ProxyBuilder.sol";
import "./ProxyTracer.sol";
import "./VersionController.sol";

contract PerpetualMaker is ProxyBuilder, ProxyTracer, VersionController {
    address internal _vault;
    address internal _latestGovernor;
    address internal _latestPerpetualImp;
    address internal _latestShareTokenImp;

    event CreatePerpetual(
        address perpetual,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        int256[7] coreParams,
        int256[5] riskParams
    );

    function createPerpetual(
        address implementation,
        address oracle,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues,
        uint256 nonce
    ) external {
        require(_verifyVersion(implementation), "invalid implementation");

        address perpetual = _deploymentAddress(implementation, nonce);
        address shareToken = _createProxy(
            _latestShareTokenImp,
            address(this),
            abi.encodeWithSignature("initialize(address)", perpetual)
        );
        address governor = _createProxy(
            _latestShareTokenImp,
            address(this),
            abi.encodeWithSignature("initialize(address)", shareToken)
        );
        bytes memory initializeData = abi.encodeWithSignature(
            "initialize(address,address,address,address,int256[7],int256[5],int256[5],int256[5])",
            msg.sender,
            oracle,
            governor,
            shareToken,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        address proxy = _createProxy2(
            implementation,
            governor,
            initializeData,
            nonce
        );
        require(proxy == perpetual, "debug1");
        _registerInstance(proxy);
        emit CreatePerpetual(
            perpetual,
            governor,
            shareToken,
            msg.sender,
            oracle,
            coreParams,
            riskParams
        );
    }

    function activeProxy(address trader, address proxy) external {
        _activeProxy(trader, proxy);
    }

    function deactiveProxy(address trader, address proxy) external {
        _deactiveProxy(trader, proxy);
    }
}
