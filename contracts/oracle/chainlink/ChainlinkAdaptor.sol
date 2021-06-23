// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interface/IOracle.sol";

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

contract ChainlinkAdaptor is Ownable, IOracle {
    address public chainlink;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;
    uint256 public maxHeartBeat;
    bool internal _isTerminated;
    string public override collateral;
    string public override underlyingAsset;

    constructor(
        address chainlink_,
        string memory collateral_,
        string memory underlyingAsset_
    ) Ownable() {
        chainlink = chainlink_;
        collateral = collateral_;
        underlyingAsset = underlyingAsset_;
    }

    function isMarketClosed() public pure override returns (bool) {
        return false;
    }

    function isTerminated() public override returns (bool) {
        checkHeartStop();
        return _isTerminated;
    }

    function priceTWAPLong() public override returns (int256, uint256) {
        if (!checkHeartStop()) {
            int256 markPrice;
            (, markPrice, , _markPriceTimestamp, ) = IChainlink(chainlink).latestRoundData();
            require(
                markPrice > 0 && markPrice <= type(int256).max / 10**10,
                "invalid oracle price"
            );
            _markPrice = markPrice * 10**10;
        }
        return (_markPrice, _markPriceTimestamp);
    }

    function priceTWAPShort() public override returns (int256, uint256) {
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
