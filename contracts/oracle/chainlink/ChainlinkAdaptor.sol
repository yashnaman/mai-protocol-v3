// SPDX-License-Identifier: BUSL-1.1
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

    function isTerminated() public view override returns (bool) {
        return _isTerminated;
    }

    function priceTWAPLong() public override returns (int256, uint256) {
        updatePrice();
        return (_markPrice, _markPriceTimestamp);
    }

    function priceTWAPShort() public override returns (int256, uint256) {
        return priceTWAPLong();
    }

    function setTerminated() external onlyOwner {
        require(!_isTerminated, "already terminated");
        _isTerminated = true;
    }

    function updatePrice() public {
        if (!_isTerminated) {
            (, _markPrice, , _markPriceTimestamp, ) = IChainlink(chainlink).latestRoundData();
            require(
                _markPrice > 0 &&
                    _markPrice <= type(int256).max / 10**10 &&
                    _markPriceTimestamp > 0,
                "invalid chainlink oracle data"
            );
            _markPrice = _markPrice * 10**10;
        }
    }
}
