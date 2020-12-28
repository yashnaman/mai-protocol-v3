// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IPoolCreator.sol";
import "./interface/ISymbolService.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";

import "./Getter.sol";
import "./Governance.sol";
import "./LibraryEvents.sol";
import "./Perpetual.sol";
import "./Storage.sol";
import "./Type.sol";

contract LiquidityPool is Storage, Perpetual, Getter, Governance, LibraryEvents {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using AMMModule for LiquidityPoolStorage;

    event CreatePerpetual(
        uint256 perpetualIndex,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        address collateral,
        int256[9] coreParams,
        int256[5] riskParams
    );
    event RunLiquidityPool();

    function initialize(
        address operator,
        address collateral,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) external initializer {
        _liquidityPool.initialize(
            collateral,
            operator,
            governor,
            shareToken,
            isFastCreationEnabled
        );
    }

    function createPerpetual(
        address oracle,
        int256[9] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        if (!_liquidityPool.isInitialized || _liquidityPool.isFastCreationEnabled) {
            require(msg.sender == _liquidityPool.operator, "only operator can create perpetual");
        } else {
            require(msg.sender == _liquidityPool.governor, "only governor can create perpetual");
        }
        uint256 perpetualIndex = _liquidityPool.perpetuals.length;
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals.push();
        perpetual.initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        ISymbolService service =
            ISymbolService(IPoolCreator(_liquidityPool.factory).symbolService());
        service.allocateSymbol(address(this), perpetualIndex);
        if (_liquidityPool.isInitialized) {
            perpetual.setNormalState();
        }
        emit CreatePerpetual(
            perpetualIndex,
            _liquidityPool.governor,
            _liquidityPool.shareToken,
            _liquidityPool.operator,
            oracle,
            _liquidityPool.collateralToken,
            coreParams,
            riskParams
        );
    }

    function runLiquidityPool() external onlyOperator {
        require(!_liquidityPool.isInitialized, "pool is already running");
        uint256 length = _liquidityPool.perpetuals.length;
        require(length > 0, "there should be at least 1 perpetual to run");
        for (uint256 i = 0; i < length; i++) {
            _liquidityPool.perpetuals[i].setNormalState();
        }
        _liquidityPool.isInitialized = true;
        emit RunLiquidityPool();
    }

    function getClaimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }

    function claimFee(address claimer, int256 amount) external nonReentrant {
        _liquidityPool.claimFee(claimer, amount);
    }

    function addLiquidity(int256 cashToAdd) external payable syncState nonReentrant {
        _liquidityPool.addLiquidity(cashToAdd);
    }

    function removeLiquidity(int256 shareToRemove) external syncState nonReentrant {
        _liquidityPool.removeLiquidity(shareToRemove);
    }

    bytes[50] private __gap;
}
