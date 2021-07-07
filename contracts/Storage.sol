// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./interface/IPoolCreatorFull.sol";
import "./module/LiquidityPoolModule.sol";
import "./Type.sol";

contract Storage is ContextUpgradeable {
    using SafeMathUpgradeable for uint256;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    LiquidityPoolStorage internal _liquidityPool;

    modifier onlyExistedPerpetual(uint256 perpetualIndex) {
        require(perpetualIndex < _liquidityPool.perpetualCount, "perpetual not exist");
        _;
    }

    modifier onlyAMMKeeper(uint256 perpetualIndex) {
        // check if whitelist is set locally.
        //  - if not, check default whitelist in pool creator;
        //  - if set, check if sender is in the local whitelist;
        EnumerableSetUpgradeable.AddressSet storage whitelist = _liquidityPool
        .perpetuals[perpetualIndex]
        .ammKeepers;
        if (whitelist.length() == 0) {
            require(
                IPoolCreatorFull(_liquidityPool.creator).isKeeper(_msgSender()),
                "caller must be keeper"
            );
        } else {
            require(whitelist.contains(_msgSender()), "caller must be keeper");
        }
        _;
    }

    modifier onlyTraderKeeper(uint256 perpetualIndex) {
        EnumerableSetUpgradeable.AddressSet storage whitelist = _liquidityPool
        .perpetuals[perpetualIndex]
        .traderKeepers;
        require(
            whitelist.length() == 0 || whitelist.contains(_msgSender()),
            "caller must be keeper"
        );
        _;
    }

    modifier syncState(bool ignoreTerminated) {
        uint256 currentTime = block.timestamp;
        _liquidityPool.updateFundingState(currentTime);
        _liquidityPool.updatePrice(ignoreTerminated);
        _;
        _liquidityPool.updateFundingRate();
    }

    modifier onlyAuthorized(address trader, uint256 privilege) {
        require(
            _liquidityPool.isAuthorized(trader, _msgSender(), privilege),
            "unauthorized caller"
        );
        _;
    }

    bytes32[28] private __gap;
}
