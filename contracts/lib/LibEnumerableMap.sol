// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

library LibEnumerableMap {

    using SafeMath for uint256;

    struct Entry {
        bytes32 _key;
        bytes32 _data;
    }

    struct GenericEnumerableMap {
        Entry[] _entries;
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(GenericEnumerableMap storage map, bytes32 key, bytes32 data) internal returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) {
            map._entries.push(Entry({ _key: key, _data: data }));
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex.sub(1)]._data = data;
            return false;
        }
    }

    function get(GenericEnumerableMap storage map, bytes32 key) internal view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "not exist");
        return map._entries[keyIndex.sub(1)]._data;
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(GenericEnumerableMap storage map, bytes32 key) internal view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(GenericEnumerableMap storage map) internal view returns (uint256) {
        return map._entries.length;
    }

   /**
    * @dev Returns the element stored at position `index` in the set. O(1).
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(GenericEnumerableMap storage map, uint256 index) internal view returns (bytes32) {
        require(map._entries.length > index, "index out of bounds");
        return map._entries[index]._data;
    }

    function keyAt(GenericEnumerableMap storage map, uint256 index) internal view returns (bytes32) {
        require(map._entries.length > index, "index out of bounds");
        return map._entries[index]._key;
    }

    /**
     * @dev Returns the position `index` for given key.
     */
    function index(GenericEnumerableMap storage map, bytes32 key) internal view returns (uint256) {
        return map._indexes[key];
    }
}