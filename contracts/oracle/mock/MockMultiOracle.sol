// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "../../interface/IOracle.sol";

contract MockMultiOracle is Ownable {
    struct Single {
        string collateral;
        string underlyingAsset;
        int256 price;
        uint256 timestamp;
        bool isMarketClosed;
        bool isTerminated;
    }
    mapping(uint256 => Single) markets;
    
    // @dev if the time since _markPriceTimestamp exceeds this threshold, isTerminated will
    //      be true automatically. maxHeartBeat = 0 means no limit
    uint256 public maxHeartBeat;

    constructor() Ownable() {
       
    }
    
    function setMarket(uint256 index, string memory collateral_, string memory underlyingAsset_) external onlyOwner {
        Single storage m = markets[index];
        m.collateral = collateral_;
        m.underlyingAsset = underlyingAsset_;
    }

    function setPrice(uint256 index, int256 price, uint256 timestamp) public onlyOwner {
        if (checkHeartStop(index)) {
            // keep the old price
            return;
        }
        Single storage m = markets[index];
        m.price = price;
        m.timestamp = timestamp;
    }
    
    struct Prices {
        uint256 index;
        int256 price;
    }
    
    function setPrices(Prices[] memory prices, uint256 timestamp) external onlyOwner {
        for (uint i = 0; i < prices.length; i++) {
            setPrice(prices[i].index, prices[i].price, timestamp);
        }
    }

    function setMarketClosed(uint256 index, bool isMarketClosed_) external onlyOwner {
        Single storage m = markets[index];
        m.isMarketClosed = isMarketClosed_;
    }
    
    function setTerminated(uint256 index, bool isTerminated_) external onlyOwner {
        Single storage m = markets[index];
        m.isTerminated = isTerminated_;
    }

    function setMaxHeartBeat(uint256 maxHeartBeat_) external onlyOwner {
        maxHeartBeat = maxHeartBeat_;
    }

    function collateral(uint256 index) external view returns (string memory) {
        Single storage m = markets[index];
        return m.collateral;
    }

    function underlyingAsset(uint256 index) external view returns (string memory) {
        Single storage m = markets[index];
        return m.underlyingAsset;
    }

    function priceTWAPLong(uint256 index) external view returns (int256 newPrice, uint256 newTimestamp) {
        Single storage m = markets[index];
        return (m.price, m.timestamp);
    }

    function priceTWAPShort(uint256 index) external view returns (int256 newPrice, uint256 newTimestamp) {
        Single storage m = markets[index];
        return (m.price, m.timestamp);
    }

    function isMarketClosed(uint256 index) external view returns (bool) {
        Single storage m = markets[index];
        return m.isMarketClosed;
    }

    function isTerminated(uint256 index) external returns (bool) {
        checkHeartStop(index);
        Single storage m = markets[index];
        return m.isTerminated;
    }

    function checkHeartStop(uint256 index) public returns (bool) {
        Single storage m = markets[index];
        if (maxHeartBeat == 0 || m.timestamp == 0) {
            return false;
        }
        if (block.timestamp > m.timestamp + maxHeartBeat) {
            m.isTerminated = true;
            return true;
        }
        return false;
    }
}

// note: wrapped by TransparentUpgradeableProxy
contract MockSingleOracle is Initializable, IOracle {
    MockMultiOracle private _multiOracle;
    uint256 private _index;

    function initialize(MockMultiOracle multiOracle_, uint256 index_) external initializer {
        _multiOracle = multiOracle_;
       _index = index_;
    }
    
    function collateral() external override view returns (string memory) {
        return _multiOracle.collateral(_index);
    }

    function underlyingAsset() external override view returns (string memory) {
        return _multiOracle.underlyingAsset(_index);
    }

    function priceTWAPLong() external override view returns (int256 newPrice, uint256 newTimestamp) {
         return _multiOracle.priceTWAPLong(_index);
    }

    function priceTWAPShort() external override view returns (int256 newPrice, uint256 newTimestamp) {
        return _multiOracle.priceTWAPShort(_index);
    }

    function isMarketClosed() external override view returns (bool) {
        return _multiOracle.isMarketClosed(_index);
    }

    function isTerminated() external override returns (bool) {
        return _multiOracle.isTerminated(_index);
    }
}

