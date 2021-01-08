// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeMathExt.sol";

contract Implementation is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeMathExt for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct VersionDescription {
        address creator;
        uint256 creationTime;
        uint256 compatibility;
        string note;
    }

    EnumerableSet.AddressSet internal _versions;
    mapping(address => VersionDescription) internal _descriptions;

    event AddVersion(address implementation);

    constructor() Ownable() {}

    /**
     * @notice Add the version of implementation
     * @param implementation The implementation
     * @param compatibility The compatibility of the implementation
     * @param note The note of the implementation
     */
    function addVersion(
        address implementation,
        uint256 compatibility,
        string calldata note
    ) external onlyOwner {
        require(implementation != address(0), "invalid implementation");
        require(implementation.isContract(), "implementation must be contract");
        require(!_versions.contains(implementation), "implementation is already existed");

        _versions.add(implementation);
        _descriptions[implementation] = VersionDescription({
            creator: msg.sender,
            creationTime: block.timestamp,
            compatibility: compatibility,
            note: note
        });
        emit AddVersion(implementation);
    }

    /**
     * @notice Get the latest version of implementation
     * @return address The latest version of implementation
     */
    function getLatestVersion() public view returns (address) {
        require(_versions.length() > 0, "no version");
        return _versions.at(_versions.length() - 1);
    }

    /**
     * @notice Get the description of implementation
     * @param implementation The implementation
     * @return creator The creator of the implementation
     * @return creationTime The create time of the implementation
     * @return compatibility The compatibility of the implementation
     * @return note The note of the implementation
     */
    function getDescription(address implementation)
        public
        view
        returns (
            address creator,
            uint256 creationTime,
            uint256 compatibility,
            string memory note
        )
    {
        require(isVersionValid(implementation), "implementation is invalid");
        creator = _descriptions[implementation].creator;
        creationTime = _descriptions[implementation].creationTime;
        compatibility = _descriptions[implementation].compatibility;
        note = _descriptions[implementation].note;
    }

    /**
     * @notice Check if the version of the implementation is valid
     * @param implementation The implementation
     * @return bool If the version of the implementation is valid
     */
    function isVersionValid(address implementation) public view returns (bool) {
        return _versions.contains(implementation);
    }

    /**
     * @notice Check if the version of base is compatible with the version of target
     * @param base The base implementation
     * @param target The target implementation
     * @return bool If the version of base is compatible with the version of target
     */
    function isVersionCompatibleWith(address base, address target) public view returns (bool) {
        require(isVersionValid(base), "base version is invalid");
        require(isVersionValid(target), "target version is invalid");
        return _descriptions[target].compatibility >= _descriptions[base].compatibility;
    }

    /**
     * @dev List available versions
     * @param start The start index of all versions
     * @param count The count of listed versions
     * @return result The listed versions
     */
    function listAvailableVersions(uint256 start, uint256 count)
        internal
        view
        returns (address[] memory result)
    {
        uint256 total = _versions.length();
        if (start >= total) {
            return result;
        }
        uint256 stop = start.add(count).min(total);
        result = new address[](stop.sub(start));
        for (uint256 i = start; i < stop; i++) {
            result[i.sub(start)] = _versions.at(i);
        }
    }
}
