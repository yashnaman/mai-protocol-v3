// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./ProxyBuilder.sol";
import "./ProxyTracer.sol";
import "./VersionController.sol";

contract PerpetualMaker is ProxyBuilder, ProxyTracer, VersionController {
    address internal _vault;

    event CreatePerpetual(
        address proxy,
        address operator,
        address oracle,
        address implementation,
        int256[14] arguments
    );

    function createPerpetual(
        string calldata symbol,
        address implementation,
        address oracle,
        int256[14] calldata arguments
    ) external {
        require(_verifyVersion(implementation), "invalid implementation");
        bytes memory initializeData = abi.encodeWithSignature(
            "initialize(string,address,address,address,int256[])",
            symbol,
            oracle,
            msg.sender,
            _vault,
            arguments
        );
        address newProxy = _createProxy(
            implementation,
            address(this),
            initializeData
        );
        _registerInstance(newProxy, implementation);
        emit CreatePerpetual(
            newProxy,
            msg.sender,
            oracle,
            implementation,
            arguments
        );
    }
}
