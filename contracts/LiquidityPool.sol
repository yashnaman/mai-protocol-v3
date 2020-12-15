// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IFactory.sol";

import "./module/CoreModule.sol";
import "./module/MarketModule.sol";

import "./Events.sol";
import "./AMM.sol";
import "./Governance.sol";
import "./Trade.sol";
import "./Type.sol";
import "./Settlement.sol";
import "./Storage.sol";
import "./Getter.sol";

contract LiquidityPool is Storage, Trade, AMM, Settlement, Getter, Governance {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using MarketModule for Market;
    using CoreModule for Core;

    event Finalize();
    event CreateMarket(
        uint256 marketIndex,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        address collateral,
        int256[8] coreParams,
        int256[5] riskParams
    );

    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken
    ) external initializer {
        _core.initialize(collateral, operator, governor, shareToken);
    }

    function createMarket(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        require(
            (!_core.isFinalized && msg.sender == _core.operator) || msg.sender == _core.governor,
            "operation is forbidden after finalized"
        );
        uint256 marketIndex = _core.markets.length;
        Market storage market = _core.markets.push();
        market.initialize(
            marketIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        emit CreateMarket(
            marketIndex,
            _core.governor,
            _core.shareToken,
            _core.operator,
            oracle,
            _core.collateral,
            coreParams,
            riskParams
        );
    }

    function finalize() external onlyOperator {
        require(!_core.isFinalized, "core is already finalized");
        uint256 length = _core.markets.length;
        for (uint256 i = 0; i < length; i++) {
            _core.markets[i].enterNormalState();
        }
        _core.isFinalized = true;
        emit Finalize();
    }

    bytes[50] private __gap;
}
