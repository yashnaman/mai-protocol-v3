// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../libraries/EnumerableMap.sol";
import "../libraries/SafeCastExt.sol";

contract VersionController {
    using SafeMath for uint256;
    using SafeCastExt for address;
    using SafeCastExt for bytes32;
    using EnumerableMap for EnumerableMap.GenericEnumerableMap;

    enum VersionState { NULL, READY, DEPRECATED }

    EnumerableMap.GenericEnumerableMap internal _versions;

    // struct VersionInfo {
    //     bool deprecated;
    // }

    event AddVersion(address implementation);
    event RevokeVersion(address implementation);

    function _addVersion(address implementation) internal {
        require(implementation != address(0), "invalid implementation");

        bool notExist = _versions.set(implementation.toBytes32(), _toBytes32(VersionState.READY));
        require(notExist, "duplicated");

        emit AddVersion(implementation);
    }

    function _revokeVersion(address implementation) internal {
        require(implementation != address(0), "invalid implementation");

        bool notExist = _versions.set(
            implementation.toBytes32(),
            _toBytes32(VersionState.DEPRECATED)
        );
        require(!notExist, "not exist");

        emit RevokeVersion(implementation);
    }

    function _verifyVersion(address implementation) internal view returns (bool) {
        VersionState state = _toVersionState(_versions.get(implementation.toBytes32()));
        return state == VersionState.READY;
    }

    function _retrieveVersionList(uint256 begin, uint256 end)
        internal
        view
        returns (address[] memory)
    {
        address[] memory slice = new address[](end.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            slice[i.sub(begin)] = _versions.keyAt(i).toAddress();
        }
        return slice;
    }

    function _toVersionState(bytes32 value) private pure returns (VersionState) {
        return VersionState(uint256(value));
    }

    function _toBytes32(VersionState state) private pure returns (bytes32) {
        return bytes32(uint256(state));
    }
}
