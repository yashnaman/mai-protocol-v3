// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeMathExt.sol";

import "hardhat/console.sol";

contract Tracer {
    using SafeMath for uint256;
    using SafeMathExt for uint256;
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
    /**
     * @notice Get the count of the liquidity pools
     * @return uint256 The count of the liquidity pools
     */
    function getLiquidityPoolCount() public view returns (uint256) {
        return _liquidityPoolSet.length();
    }

    /**
     * @notice Check if the liquidity pool exists
     * @param liquidityPool The address of liquidity pool
     * @return bool If the liquidity pool exists
     */
    function isLiquidityPool(address liquidityPool) public view returns (bool) {
        return _liquidityPoolSet.contains(liquidityPool);
    }

    /**
     * @notice Get the liquidity pools whose index between begin and end
     * @param begin The begin index
     * @param end The end index
     * @return result The addresses of the liquidity pools whose index between begin and end
     */
    function listLiquidityPools(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        return _addressSetToList(_liquidityPoolSet, begin, end);
    }

    /**
     * @notice Get the count of the liquidity pools owned by the operator
     * @param operator The address of operator
     * @return uint256 The count of the liquidity pools owned by the operator
     */
    function getOwnedLiquidityPoolsCountOf(address operator) public view returns (uint256) {
        return _operatorOwnedLiquidityPools[operator].length();
    }

    /**
     * @notice Get the liquidity pools owned by the operator and whose index between begin and end
     * @param operator The address of the operator
     * @param begin The begin index
     * @param end The end index
     * @return result The liquidity pools owned by the operator and whose index between begin and end
     */
    function listLiquidityPoolOwnedBy(
        address operator,
        uint256 begin,
        uint256 end
    ) public view returns (address[] memory result) {
        return _addressSetToList(_operatorOwnedLiquidityPools[operator], begin, end);
    }

    /**
     * @notice Change the operator of the liquidity pool
     * @param liquidityPool The address of the liquidity pool
     * @param operator The address of the new operator
     */
    function setLiquidityPoolOwnership(address liquidityPool, address operator)
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

    /**
     * @dev Register the liquidity pool, the liquidity pool should not be registered before
     * @param liquidityPool The address of the liquidity pool
     * @param operator The address of the operator
     */
    function _registerLiquidityPool(address liquidityPool, address operator) internal {
        require(liquidityPool != address(0), "invalid liquidity pool address");
        bool success = _liquidityPoolSet.add(liquidityPool);
        require(success, "liquidity pool exists");
        _operatorOwnedLiquidityPools[operator].add(liquidityPool);
        _liquidityPoolOwners[liquidityPool] = operator;
    }

    // =========================== Active Liquidity Pool of Trader ===========================
    /**
     * @notice Get the count of the trader's active liquidity pools
     * @param trader The address of trader
     * @return uint256 The count of the trader's active liquidity pools
     */
    function getActiveLiquidityPoolCountOf(address trader) public view returns (uint256) {
        return _traderActiveLiquidityPools[trader].length();
    }

    /**
     * @notice Check if the perpetual is active for the trader
     * @param trader The address of trader
     * @param liquidityPool The address of liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bool If the perpetual of liquidity pool is active for the trader
     */
    function isActiveLiquidityPoolOf(
        address trader,
        address liquidityPool,
        uint256 perpetualIndex
    ) public view returns (bool) {
        return
            _traderActiveLiquidityPools[trader].contains(
                _getPerpetualKey(liquidityPool, perpetualIndex)
            );
    }

    /**
     * @notice Get the liquidity pools whose index between begin and end and active for the trader
     * @param trader The address of the trader
     * @param begin The begin index
     * @param end The end index
     * @return result The addresses of the liquidity pools whose index between begin and end and active for the trader
     */
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

    /**
     * @notice Activate the perpetual for the trader
     * @param trader The address of the trader
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bool If the activation is successful
     */
    function activatePerpetualFor(address trader, uint256 perpetualIndex)
        external
        onlyLiquidityPool
        returns (bool)
    {
        bytes32 key = _getPerpetualKey(msg.sender, perpetualIndex);
        if (_perpetualUIDs[key].liquidityPool == address(0)) {
            _perpetualUIDs[key] = PerpetualUID({
                liquidityPool: msg.sender,
                perpetualIndex: perpetualIndex
            });
        }
        return _traderActiveLiquidityPools[trader].add(key);
    }

    /**
     * @notice Deactivate the perpetual for the trader
     * @param trader The address of the trader
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bool If the deactivation is successful
     */
    function deactivatePerpetualFor(address trader, uint256 perpetualIndex)
        external
        onlyLiquidityPool
        returns (bool)
    {
        return
            _traderActiveLiquidityPools[trader].remove(
                _getPerpetualKey(msg.sender, perpetualIndex)
            );
    }

    // =========================== Active Liquidity Pool of Trader ===========================
    /**
     * @dev Get addresses in set whose index between begin and end
     * @param set The address set
     * @param begin The begin index
     * @param end The end index
     * @return result The addresses in set whose index between begin and end
     */
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

    /**
     * @dev Get the key of the perpetual
     * @param liquidityPool The address of the liquidity pool which the perpetual belongs to
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bytes32 The key of the perpetual
     */
    function _getPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}
