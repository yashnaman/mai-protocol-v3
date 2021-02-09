// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeMathExt.sol";

contract VersionControl is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeMathExt for uint256;
    using Utils for EnumerableSet.AddressSet;
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
     * @notice Create the implementation of the liquidity pool by sender. The implementation should not be created before
     * @param implementation The address of the implementation
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
     * @notice Get the latest created implementation of liquidity pool, revert if there is no implementation
     * @return address The address of the latest implementation
     */
    function getLatestVersion() public view returns (address) {
        require(_versions.length() > 0, "no version");
        return _versions.at(_versions.length() - 1);
    }

    /**
     * @notice Get the description of the implementation of liquidity pool.
     *         Description contains creator, create time, compatibility and note
     * @param implementation The address of the implementation
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
     * @notice Check if the implementation of liquidity pool is created
     * @param implementation The address of the implementation
     * @return bool True if the implementation is created
     */
    function isVersionValid(address implementation) public view returns (bool) {
        return _versions.contains(implementation);
    }

    /**
     * @notice Check if the implementation of liquidity pool target is compatible with the implementation base.
     *         Being compatible means having larger compatibility
     * @param target The address of implementation target
     * @param base The address of implementation base
     * @return bool True if the implementation target is compatible with the implementation base
     */
    function isVersionCompatible(address target, address base) public view returns (bool) {
        require(isVersionValid(target), "target version is invalid");
        require(isVersionValid(base), "base version is invalid");
        return _descriptions[target].compatibility >= _descriptions[base].compatibility;
    }

    /**
     * @dev     Get a certain number of implementations of liquidity pool within range [begin, end)
     * @param   begin   The index of first element to retrieve.
     * @param   end     The end index of element, exclusive.
     * @return  result  An array of addresses of current implementations.
     */
    function listAvailableVersions(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        result = _versions.toArray(begin, end);
    }
}
