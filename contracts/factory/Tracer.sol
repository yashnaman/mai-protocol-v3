// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeCastExt.sol";
import "../libraries/SafeMathExt.sol";

import "hardhat/console.sol";

contract Tracer {
    using SafeMath for uint256;
    using SafeMathExt for uint256;
    using SafeCastExt for address;
    using SafeCastExt for bytes32;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct MUID {
        address liquidityPool;
        uint256 marketIndex;
    }

    uint256 internal nextGUID;
    // hash(muid) => MUID {}
    mapping(bytes32 => MUID) internal _muids;
    // guid => liquidity pool address
    mapping(uint256 => address) internal _sharedLiquidityPoolGUIDIndex;
    // liquidity pool address[]
    EnumerableSet.AddressSet internal _sharedLiquidityPoolSet;
    // trader => hash(muid) []
    mapping(address => EnumerableSet.Bytes32Set) internal _traderActiveSharedLiquidityPools;

    modifier onlySharedLiquidityPool() {
        require(isSharedLiquidityPool(msg.sender), "call is not liquidity pool instance");
        _;
    }

    // =========================== Liquidity Pool ===========================
    function sharedLiquidityPoolCount() public view returns (uint256) {
        return _sharedLiquidityPoolSet.length();
    }

    function isSharedLiquidityPool(address liquidityPool) public view returns (bool) {
        return _sharedLiquidityPoolSet.contains(liquidityPool);
    }

    function listSharedLiquidityPools(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        require(end > begin, "begin should be lower than end");
        uint256 length = _sharedLiquidityPoolSet.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new address[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _sharedLiquidityPoolSet.at(i);
        }
        return result;
    }

    function findSharedLiquidityPoolByIndex(uint256 guid) public view returns (address) {
        return _sharedLiquidityPoolGUIDIndex[guid];
    }

    function _registerSharedLiquidityPool(address liquidityPool) internal {
        require(liquidityPool != address(0), "invalid liquidity pool address");
        bool notExist = _sharedLiquidityPoolSet.add(liquidityPool);
        require(notExist, "liquidity pool exists");
        _sharedLiquidityPoolGUIDIndex[nextGUID] = liquidityPool;
        nextGUID = nextGUID.add(1);
    }

    // =========================== Active Liquidity Pool of Trader ===========================
    function activeSharedLiquidityPoolCountOf(address trader) public view returns (uint256) {
        return _traderActiveSharedLiquidityPools[trader].length();
    }

    function isActiveSharedLiquidityPoolOf(
        address trader,
        address liquidityPool,
        uint256 marketIndex
    ) public view returns (bool) {
        return
            _traderActiveSharedLiquidityPools[trader].contains(
                _poolMarketKey(liquidityPool, marketIndex)
            );
    }

    function listActiveSharedLiquidityPoolsOf(
        address trader,
        uint256 begin,
        uint256 end
    ) public view returns (MUID[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = _traderActiveSharedLiquidityPools[trader].length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new MUID[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _muids[_traderActiveSharedLiquidityPools[trader].at(i)];
        }
        return result;
    }

    function activateSharedLiquidityPoolFor(address trader, uint256 marketIndex)
        external
        onlySharedLiquidityPool
        returns (bool)
    {
        bytes32 key = _poolMarketKey(msg.sender, marketIndex);
        if (_muids[key].liquidityPool == address(0)) {
            _muids[key] = MUID({ liquidityPool: msg.sender, marketIndex: marketIndex });
        }
        return _traderActiveSharedLiquidityPools[trader].add(key);
    }

    function deactivateSharedLiquidityPoolFor(address trader, uint256 marketIndex)
        external
        onlySharedLiquidityPool
        returns (bool)
    {
        return
            _traderActiveSharedLiquidityPools[trader].remove(
                _poolMarketKey(msg.sender, marketIndex)
            );
    }

    function _poolMarketKey(address liquidityPool, uint256 marketIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, marketIndex));
    }
}
