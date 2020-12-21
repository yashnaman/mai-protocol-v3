// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface ILiquidityPool {
    function liquidityPoolInfo()
        external
        view
        returns (
            // [0] factory
            address[6] memory addresses,
            int256[7] memory nums,
            uint256 perpetualCount,
            uint256 fundingTime
        );
}

contract SymbolService is Ownable {
    
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    struct PerpetualUID {
        address liquidityPool;
        uint256 perpetualIndex;
    }

    mapping(uint256 => PerpetualUID) internal _perpetualUIDs;
    mapping(bytes32 => EnumerableSet.UintSet) internal _perpetualSymbols;
    uint256 internal _nextSymbol;
    uint256 internal _reservedSymbolCount;
    EnumerableSet.AddressSet internal _whitelistedFactories;
    
    event AssignSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol);
    event AddWhitelistedFactory(address factory);
    event RemoveWhitelistedFactory(address factory);

    constructor(uint256 reservedSymbolCount) Ownable() {
        _nextSymbol = reservedSymbolCount;
        _reservedSymbolCount = reservedSymbolCount;
    }

    function getPerpetualUID(uint256 symbol) public view returns (PerpetualUID memory perpetualUID) {
        perpetualUID = _perpetualUIDs[symbol];
        require(perpetualUID.liquidityPool != address(0), "symbol not found");
    }

    function getSymbols(PerpetualUID memory perpetualUID) public view returns (uint256[] memory symbols) {
        bytes32 key = _poolPerpetualKey(perpetualUID);
        uint256 len = _perpetualSymbols[key].length();
        if (len == 0) {
            return symbols;
        }
        symbols = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            symbols[i] = _perpetualSymbols[key].at(i);
        }
    }
    
    function assignNormalSymbol(PerpetualUID memory perpetualUID) public returns (uint256 symbol) {
        require(Address.isContract(msg.sender), "must called by contract");
        (address[6] memory addresses, , ,) = ILiquidityPool(msg.sender).liquidityPoolInfo();
        require(_whitelistedFactories.contains(addresses[0]), "wrong factory");
        require(_nextSymbol <= type(uint256).max, "not enough symbol");
        
        bytes32 key = _poolPerpetualKey(perpetualUID);
        require(_perpetualSymbols[key].length() == 0, "perpetual already exists");
        addPerpetualUID(perpetualUID, _nextSymbol, key);
        symbol = _nextSymbol;
        _nextSymbol = _nextSymbol + 1;
    }

    function assignReservedSymbol(PerpetualUID memory perpetualUID, uint256 symbol) public onlyOwner {
        require(symbol < _reservedSymbolCount, "symbol exceeds reserved symbol count");
        require(_perpetualUIDs[symbol].liquidityPool == address(0), "symbol already exists"); 
        bytes32 key = _poolPerpetualKey(perpetualUID);
        require(_perpetualSymbols[key].length() == 1 && _perpetualSymbols[key].at(0) >= _reservedSymbolCount, "perpetual must have normal symbol and mustn't have reversed symbol");
        addPerpetualUID(perpetualUID, symbol, key);
    }
    
    function addPerpetualUID(PerpetualUID memory perpetualUID, uint256 symbol, bytes32 key) internal {
        _perpetualUIDs[symbol] = perpetualUID;
        _perpetualSymbols[key].add(symbol);
        emit AssignSymbol(perpetualUID.liquidityPool, perpetualUID.perpetualIndex, symbol);
    }
    
    function _poolPerpetualKey(PerpetualUID memory perpetualUID)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(perpetualUID.liquidityPool, perpetualUID.perpetualIndex));
    }

    function isWhitelistedFactory(address factory) public view returns (bool) {
        return _whitelistedFactories.contains(factory);
    }
    
    function addWhitelistedFactory(address factory) public onlyOwner {
        require(! isWhitelistedFactory(factory), "factory already exists");
        _whitelistedFactories.add(factory);
        emit AddWhitelistedFactory(factory);
    }
    
    function removeWhitelistedFactory(address factory) public onlyOwner {
        require(isWhitelistedFactory(factory), "factory not found");
        _whitelistedFactories.remove(factory);
        emit RemoveWhitelistedFactory(factory);
    }

}