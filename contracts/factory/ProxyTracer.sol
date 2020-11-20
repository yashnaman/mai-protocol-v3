// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../libraries/SafeCastExt.sol";

contract ProxyTracer {
    using SafeMath for uint256;
    using SafeCastExt for address;
    using SafeCastExt for bytes32;
    using EnumerableSet for EnumerableSet.AddressSet;

    // address of proxy => struct {
    //     address of proxy
    //     address of implementation
    // }
    EnumerableSet.AddressSet internal _proxyInstances;
    mapping(address => EnumerableSet.AddressSet) internal _traderActiveProxies;

    function _registerInstance(address proxy) internal {
        require(proxy != address(0), "invalid proxy");
        bool notExist = _proxyInstances.add(proxy);
        require(notExist, "duplicated");
    }

    function _deregisterInstance(address proxy) internal {
        require(proxy != address(0), "invalid proxy");
        bool notExist = _proxyInstances.remove(proxy);
        require(!notExist, "not exist");
    }

    function _isInstance(address proxy) internal view returns (bool) {
        return _proxyInstances.contains(proxy);
    }

    function _instanceCount() internal view returns (uint256) {
        return _proxyInstances.length();
    }

    function _listInstances(uint256 begin, uint256 end)
        internal
        view
        returns (address[] memory)
    {
        require(end < _proxyInstances.length(), "exceeded");
        require(end > begin, "0 length");

        address[] memory slice = new address[](end.sub(begin));
        for (uint256 i = begin; i < end; i++) {
            slice[i.sub(begin)] = _proxyInstances.at(i);
        }
        return slice;
    }

    function _activeProxy(address trader, address proxy)
        internal
        returns (bool)
    {
        require(_isInstance(msg.sender), "");
        require(trader != address(0), "");
        require(proxy != address(0), "");
        return _traderActiveProxies[trader].add(proxy);
    }

    function _deactiveProxy(address trader, address proxy)
        internal
        returns (bool)
    {
        require(_isInstance(msg.sender), "");
        require(trader != address(0), "");
        require(proxy != address(0), "");
        return _traderActiveProxies[trader].remove(proxy);
    }
}
