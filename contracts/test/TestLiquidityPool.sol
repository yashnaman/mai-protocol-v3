// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/AMMModule.sol";
import "../module/PerpetualModule.sol";

import "../LiquidityPool.sol";
import "../Type.sol";

contract TestLiquidityPool is LiquidityPool {
    using PerpetualModule for PerpetualStorage;

    function createPerpetual2(
        address oracle,
        int256[9] calldata coreParams,
        int256[5] calldata riskParams
    ) external {
        uint256 perpetualIndex = _liquidityPool.perpetuals.length;
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals.push();
        perpetual.initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            riskParams,
            riskParams
        );
    }

    function setPoolCash(int256 amount) public {
        _liquidityPool.poolCash = amount;
    }

    function setMarginAccount(
        uint256 perpetualIndex,
        address trader,
        int256 cash,
        int256 position
    ) external {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.marginAccounts[trader].cash = cash;
        perpetual.marginAccounts[trader].position = position;
    }

    function setCollateralToken(address collateralToken, uint256 scaler) public {
        _liquidityPool.collateralToken = collateralToken;
        _liquidityPool.scaler = scaler;
    }

    function setShareToken(address shareToken) public {
        _liquidityPool.shareToken = shareToken;
    }

    function setUnitAccumulativeFunding(uint256 perpetualIndex, int256 unitAccumulativeFunding)
        public
    {
        _liquidityPool.perpetuals[perpetualIndex].unitAccumulativeFunding = unitAccumulativeFunding;
    }
}
