// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IFactory.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";

import "./Events.sol";
import "./Getter.sol";
import "./Governance.sol";
import "./Perpetual.sol";
import "./Storage.sol";
import "./Settlement.sol";
import "./Storage.sol";
import "./Type.sol";

contract LiquidityPool is Storage, Perpetual, Settlement, Getter, Governance {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using AMMModule for LiquidityPoolStorage;

    event Finalize();
    event CreatePerpetual(
        uint256 perpetualIndex,
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
        _liquidityPool.initialize(collateral, operator, governor, shareToken);
    }

    function createPerpetual(
        address oracle,
        int256[8] calldata coreParams,
        int256[5] calldata riskParams,
        int256[5] calldata minRiskParamValues,
        int256[5] calldata maxRiskParamValues
    ) external {
        require(
            (!_liquidityPool.isFinalized && msg.sender == _liquidityPool.operator) ||
                msg.sender == _liquidityPool.governor,
            "operation is forbidden after finalized"
        );
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
        emit CreatePerpetual(
            perpetualIndex,
            _liquidityPool.governor,
            _liquidityPool.shareToken,
            _liquidityPool.operator,
            oracle,
            _liquidityPool.collateral,
            coreParams,
            riskParams
        );
    }

    function finalize() external onlyOperator {
        require(!_liquidityPool.isFinalized, "core is already finalized");
        uint256 length = _liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            _liquidityPool.perpetuals[i].enterNormalState();
        }
        _liquidityPool.isFinalized = true;
        emit Finalize();
    }

    function claimableFee(address claimer) public view returns (int256) {
        return _liquidityPool.claimableFees[claimer];
    }

    function claimFee(int256 amount) external nonReentrant {
        _liquidityPool.claimFee(msg.sender, amount);
    }

    function donateInsuranceFund(int256 amount) external payable nonReentrant {
        require(amount > 0, "amount is 0");
        _liquidityPool.donateInsuranceFund(amount);
    }

    function addLiquidity(int256 cashToAdd) external payable syncState nonReentrant {
        require(cashToAdd > 0 || msg.value > 0, "amount is invalid");
        _liquidityPool.addLiquidity(cashToAdd);
    }

    function removeLiquidity(int256 shareToRemove) external syncState nonReentrant {
        require(shareToRemove > 0, "amount is invalid");
        _liquidityPool.removeLiquidity(shareToRemove);
    }

    bytes[50] private __gap;
}
