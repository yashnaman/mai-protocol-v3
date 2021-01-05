// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IPoolCreator.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";
import "./module/SignatureModule.sol";

import "./LiquidityPool.sol";
import "./Type.sol";

contract LiquidityPoolSignable is LiquidityPool {
    bytes[50] private __gap;
}
