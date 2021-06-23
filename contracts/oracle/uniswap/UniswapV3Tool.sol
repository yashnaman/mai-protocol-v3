// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";

contract UniswapV3Tool {
    function increaseObservationCardinalityNext(
        address factory,
        address[] memory path,
        uint24[] memory fees,
        uint16 observationCardinalityNext
    ) external {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "paths are too short");
        require(pathLength - 1 == fees.length, "paths and fees are mismatched");

        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool = PoolAddress.computeAddress(
                factory,
                PoolAddress.getPoolKey(path[i], path[i + 1], fees[i])
            );
            IUniswapV3PoolActions(pool).increaseObservationCardinalityNext(
                observationCardinalityNext
            );
        }
    }
}
