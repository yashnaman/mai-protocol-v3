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
        uint256 perpetualIndex;
    }

    uint256 internal nextGUID;
    // hash(muid) => MUID {}
    mapping(bytes32 => MUID) internal _muids;
    // guid => liquidity pool address
    mapping(uint256 => address) internal _liquidityPoolGUIDIndex;
    // liquidity pool address[]
    EnumerableSet.AddressSet internal _liquidityPoolSet;
    // trader => hash(muid) []
    mapping(address => EnumerableSet.Bytes32Set) internal _traderActiveLiquidityPools;

    modifier onlyLiquidityPool() {
        require(isLiquidityPool(msg.sender), "call is not liquidity pool instance");
        _;
    }

    // =========================== Liquidity Pool ===========================
    function liquidityPoolCount() public view returns (uint256) {
        return _liquidityPoolSet.length();
    }

    function isLiquidityPool(address liquidityPool) public view returns (bool) {
        return _liquidityPoolSet.contains(liquidityPool);
    }

    function listLiquidityPools(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        require(end > begin, "begin should be lower than end");
        uint256 length = _liquidityPoolSet.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new address[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _liquidityPoolSet.at(i);
        }
        return result;
    }

    function findLiquidityPoolByIndex(uint256 guid) public view returns (address) {
        return _liquidityPoolGUIDIndex[guid];
    }

    function _registerLiquidityPool(address liquidityPool) internal {
        require(liquidityPool != address(0), "invalid liquidity pool address");
        bool notExist = _liquidityPoolSet.add(liquidityPool);
        require(notExist, "liquidity pool exists");
        _liquidityPoolGUIDIndex[nextGUID] = liquidityPool;
        nextGUID = nextGUID.add(1);
    }

    // =========================== Active Liquidity Pool of Trader ===========================
    function activeLiquidityPoolCountOf(address trader) public view returns (uint256) {
        return _traderActiveLiquidityPools[trader].length();
    }

    function isActiveLiquidityPoolOf(
        address trader,
        address liquidityPool,
        uint256 perpetualIndex
    ) public view returns (bool) {
        return
            _traderActiveLiquidityPools[trader].contains(
                _poolPerpetualKey(liquidityPool, perpetualIndex)
            );
    }

    function listActiveLiquidityPoolsOf(
        address trader,
        uint256 begin,
        uint256 end
    ) public view returns (MUID[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = _traderActiveLiquidityPools[trader].length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new MUID[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _muids[_traderActiveLiquidityPools[trader].at(i)];
        }
        return result;
    }

    function activateLiquidityPoolFor(address trader, uint256 perpetualIndex)
        external
        onlyLiquidityPool
        returns (bool)
    {
        bytes32 key = _poolPerpetualKey(msg.sender, perpetualIndex);
        if (_muids[key].liquidityPool == address(0)) {
            _muids[key] = MUID({ liquidityPool: msg.sender, perpetualIndex: perpetualIndex });
        }
        return _traderActiveLiquidityPools[trader].add(key);
    }

    function deactivateLiquidityPoolFor(address trader, uint256 perpetualIndex)
        external
        onlyLiquidityPool
        returns (bool)
    {
        return
            _traderActiveLiquidityPools[trader].remove(
                _poolPerpetualKey(msg.sender, perpetualIndex)
            );
    }

    function _poolPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}
