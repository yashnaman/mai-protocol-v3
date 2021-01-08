// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";

import "../Type.sol";

contract MockAMMPriceEntries {
    struct PriceEntry {
        bool isSet;
        int256 deltaCash;
        int256 deltaPosition;
    }

    PriceEntry internal _defaultEntry;
    mapping(int256 => PriceEntry) internal _entries;

    function queryPrice(int256 tradeAmount)
        public
        view
        returns (int256 deltaCash, int256 deltaPosition)
    {
        PriceEntry storage entry = _entries[tradeAmount];
        if (entry.isSet) {
            return (entry.deltaCash, entry.deltaPosition);
        } else {
            return (_defaultEntry.deltaCash, _defaultEntry.deltaPosition);
        }
    }

    function setDefaultEntry(int256 deltaCash, int256 deltaPosition) public {
        _defaultEntry = PriceEntry({
            isSet: true,
            deltaCash: deltaCash,
            deltaPosition: deltaPosition
        });
    }

    function setEntry(
        int256 tradeAmount,
        int256 deltaCash,
        int256 deltaPosition
    ) public {
        _entries[tradeAmount] = PriceEntry({
            isSet: true,
            deltaCash: deltaCash,
            deltaPosition: deltaPosition
        });
    }
}

library MockAMMModule {
    using Math for int256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    function queryTradeWithAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 tradeAmount,
        bool partialFill
    ) public view returns (int256 deltaCash, int256 deltaPosition) {
        MockAMMPriceEntries priceHook = MockAMMPriceEntries(liquidityPool.governor);
        return priceHook.queryPrice(tradeAmount);
    }
}
