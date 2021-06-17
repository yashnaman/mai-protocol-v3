// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IChainlink {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        );
}

contract ChainlinkAdaptor is Ownable {
    address internal _chainlink;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;
    uint256 public maxHeartBeat;
    bool internal _isTerminated;
    string internal _collateral;
    string internal _underlyingAsset;

    constructor(
        address chainlink,
        string memory collateral_,
        string memory underlyingAsset_
    ) Ownable() {
        _chainlink = chainlink;
        _collateral = collateral_;
        _underlyingAsset = underlyingAsset_;
    }

    function isMarketClosed() public pure returns (bool) {
        return false;
    }

    function isTerminated() public returns (bool) {
        checkHeartStop();
        return _isTerminated;
    }

    function collateral() public view returns (string memory) {
        return _collateral;
    }

    function underlyingAsset() public view returns (string memory) {
        return _underlyingAsset;
    }

    function priceTWAPLong() public returns (int256, uint256) {
        if (!checkHeartStop()) {
            (, _markPrice, , _markPriceTimestamp, ) = IChainlink(_chainlink).latestRoundData();
            require(
                _markPrice > 0 && _markPrice <= type(int256).max / 10**10,
                "invalid oracle price"
            );
            _markPrice *= 10**10;
        }
        return (_markPrice, _markPriceTimestamp);
    }

    function priceTWAPShort() public returns (int256, uint256) {
        return priceTWAPLong();
    }

    function setMaxHeartBeat(uint256 _maxHeartBeat) external onlyOwner {
        maxHeartBeat = _maxHeartBeat;
    }

    function checkHeartStop() public returns (bool) {
        if (maxHeartBeat == 0 || _markPriceTimestamp == 0) {
            return false;
        }
        if (block.timestamp > _markPriceTimestamp + maxHeartBeat) {
            _isTerminated = true;
            return true;
        }
        return false;
    }
}
