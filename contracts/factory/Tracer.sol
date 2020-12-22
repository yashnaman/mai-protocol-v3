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

    struct PerpetualUID {
        address liquidityPool;
        uint256 perpetualIndex;
    }

    // liquidity pool address[]
    EnumerableSet.AddressSet internal _liquidityPoolSet;
    // hash(puid) => PerpetualUID {}
    mapping(bytes32 => PerpetualUID) internal _perpetualUIDs;
    // trader => hash(puid) []
    mapping(address => EnumerableSet.Bytes32Set) internal _traderActiveLiquidityPools;
    // operator => address
    mapping(address => EnumerableSet.AddressSet) internal _operatorOwnedLiquidityPools;
    mapping(address => address) internal _liquidityPoolOwners;

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
        return _addressSetToList(_liquidityPoolSet, begin, end);
    }

    function ownedLiquidityPoolsCountOf(address operator) public view returns (uint256) {
        return _operatorOwnedLiquidityPools[operator].length();
    }

    function listLiquidityPoolOwnedBy(
        address operator,
        uint256 begin,
        uint256 end
    ) public view returns (address[] memory result) {
        return _addressSetToList(_operatorOwnedLiquidityPools[operator], begin, end);
    }

    function updateLiquidityPoolOwnership(address liquidityPool, address operator)
        public
        onlyLiquidityPool
    {
        address prevOperator = _liquidityPoolOwners[liquidityPool];
        require(operator != prevOperator, "user is already operator of liquidity pool");
        bool exist = _operatorOwnedLiquidityPools[prevOperator].remove(liquidityPool);
        require(exist, "operator is not owned by previous owner");

        bool success = _operatorOwnedLiquidityPools[operator].add(liquidityPool);
        require(success, "operator is already owner of this liquidity pool");
        _liquidityPoolOwners[liquidityPool] = operator;
    }

    function _registerLiquidityPool(address liquidityPool, address operator) internal {
        require(liquidityPool != address(0), "invalid liquidity pool address");
        bool success = _liquidityPoolSet.add(liquidityPool);
        require(success, "liquidity pool exists");
        _operatorOwnedLiquidityPools[operator].add(liquidityPool);
        _liquidityPoolOwners[liquidityPool] = operator;
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
    ) public view returns (PerpetualUID[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = _traderActiveLiquidityPools[trader].length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new PerpetualUID[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = _perpetualUIDs[_traderActiveLiquidityPools[trader].at(i)];
        }
        return result;
    }

    function activateLiquidityPoolFor(address trader, uint256 perpetualIndex)
        external
        onlyLiquidityPool
        returns (bool)
    {
        bytes32 key = _poolPerpetualKey(msg.sender, perpetualIndex);
        if (_perpetualUIDs[key].liquidityPool == address(0)) {
            _perpetualUIDs[key] = PerpetualUID({
                liquidityPool: msg.sender,
                perpetualIndex: perpetualIndex
            });
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

    // =========================== Active Liquidity Pool of Trader ===========================

    function _addressSetToList(
        EnumerableSet.AddressSet storage set,
        uint256 begin,
        uint256 end
    ) internal view returns (address[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = set.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = begin.add(end).min(length);
        result = new address[](safeEnd.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            result[i.sub(begin)] = set.at(i);
        }
        return result;
    }

    function _poolPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}
