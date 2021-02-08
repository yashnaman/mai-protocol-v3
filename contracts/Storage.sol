// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./interface/IAccessControll.sol";
import "./module/LiquidityPoolModule.sol";
import "./Type.sol";

contract Storage is ContextUpgradeable {
    using SafeMathUpgradeable for uint256;
    using LiquidityPoolModule for LiquidityPoolStorage;

    LiquidityPoolStorage internal _liquidityPool;

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
            trader == _msgSender() ||
                IAccessControll(_liquidityPool.accessController).isGranted(
                    trader,
                    _msgSender(),
                    privilege
                ),
            "unauthorized operation"
        );
        _;
    }

    bytes32[50] private __gap;
}
