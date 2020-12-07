// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interface/IShareToken.sol";

import "../Type.sol";
import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";
import "./AMMCommon.sol";

library AMMTradeModule {
    using Math for int256;
    using Math for uint256;
    using SafeMathExt for int256;
    using SignedSafeMath for int256;
    using SafeMath for uint256;
    using MarginModule for Core;
    using OracleModule for Core;

    function tradeWithAMM(
        Core storage core,
        int256 tradingAmount,
        bool partialFill
    ) public view returns (int256 deltaMargin, int256 deltaPosition) {}

    function addLiquidity(
        Core storage core,
        int256 shareTotalSupply,
        int256 marginToAdd
    ) public view returns (int256 share) {}

    function removeLiquidity(
        Core storage core,
        int256 shareTotalSupply,
        int256 shareToRemove
    ) public view returns (int256 marginToRemove) {}
}
