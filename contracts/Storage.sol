// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./interface/IAccessController.sol";

import "./module/LiquidityPoolModule.sol";

import "./Type.sol";

contract Storage {
    using SafeMathUpgradeable for uint256;
    using LiquidityPoolModule for LiquidityPoolStorage;

    LiquidityPoolStorage internal _liquidityPool;
    address internal _governor;
    address internal _shareToken;

    modifier onlyNotPaused(uint256 perpetualIndex) {
        require(
            !IOracle(_liquidityPool.perpetuals[perpetualIndex].oracle).isPaused(),
            "oracle is paused"
        );
        _;
    }

    modifier onlyExistedPerpetual(uint256 perpetualIndex) {
        require(perpetualIndex < _liquidityPool.perpetuals.length, "perpetual not exist");
        _;
    }

    modifier syncState() {
        uint256 currentTime = block.timestamp;
        _liquidityPool.updateFundingState(currentTime);
        _liquidityPool.updatePrice(currentTime);
        _;
        _liquidityPool.updateFundingRate();
    }

    modifier onlyWhen(uint256 perpetualIndex, PerpetualState allowedState) {
        require(
            _liquidityPool.perpetuals[perpetualIndex].state == allowedState,
            "operation is disallowed now"
        );
        _;
    }

    modifier onlyNotWhen(uint256 perpetualIndex, PerpetualState disallowedState) {
        require(
            _liquidityPool.perpetuals[perpetualIndex].state != disallowedState,
            "operation is disallow now"
        );
        _;
    }

    modifier onlyAuthorized(address trader, uint256 privilege) {
        require(
            trader == msg.sender ||
                IAccessController(_liquidityPool.accessController).isGranted(
                    trader,
                    msg.sender,
                    privilege
                ),
            "unauthorized operation"
        );
        _;
    }

    bytes[50] private __gap;
}
