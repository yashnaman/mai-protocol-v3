// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract State {
    bool internal _emergency;
    bool internal _shuttingdown;

    modifier whenNormal() {
        require(_isNormal(), "only in normal state");
        _;
    }

    modifier whenEmergency() {
        require(_isEmergency(), "only in ermergency state");
        _;
    }

    modifier whenShuttingDown() {
        require(_isShuttingDown(), "only in shutting down state");
        _;
    }

    function _isNormal() internal view returns (bool) {
        return !_emergency && !_shuttingdown;
    }

    function _isEmergency() internal view returns (bool) {
        return _emergency;
    }

    function _isShuttingDown() internal view returns (bool) {
        return _emergency;
    }

    function _enterEmergencyState() internal whenNormal {
        _emergency = true;
    }

    function _enterShuttingDownState() internal whenEmergency {
        _emergency = false;
        _shuttingdown = true;
    }

    bytes32[50] private __gap;
}