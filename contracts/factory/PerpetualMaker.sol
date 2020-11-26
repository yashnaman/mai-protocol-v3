// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/Address.sol";

import "./ProxyBuilder.sol";
import "./PerpetualTracer.sol";
import "./VersionController.sol";

contract PerpetualMaker is ProxyBuilder, PerpetualTracer, VersionController {
    using Address for address;

    address internal _vault;
    int256 internal _vaultFeeRate;

    address internal _latestGovernor;
    address internal _latestShareTokenImp;
    address internal _latestPerpetualImp;

    constructor(address governor, address shareToken, address perpetual, address vault_, int256 vaultFeeRate_) {
        _vault = vault_;
        _vaultFeeRate = vaultFeeRate_;
        _latestGovernor = governor;
        _latestShareTokenImp = shareToken;
        _latestPerpetualImp = perpetual;

    }

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
        // address implementation,
        address oracle,
        int256[7] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues,
        uint256 nonce
    ) external returns (address) {
        // require(_verifyVersion(implementation), "invalid implementation");
        address governor = _createStaticProxy(_latestGovernor);
        address shareToken = _createStaticProxy(_latestShareTokenImp);
        address perpetual = _createPerpetualProxy(_latestPerpetualImp, governor, nonce);

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
        _registerPerpetualInstance(perpetual);
        emit CreatePerpetual(
            perpetual,
            governor,
            shareToken,
            msg.sender,
            oracle,
            coreParams,
            riskParams
        );
        return perpetual;
    }

    function vault() public view returns (address) {
        return _vault;
    }

    function vaultFeeRate() public view returns (int256) {
        return _vaultFeeRate;
    }
}

