// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

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

contract SymbolService is OwnableUpgradeable {
    
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    
    struct PerpetualUID {
        address liquidityPool;
        uint256 perpetualIndex;
    }

    mapping(uint256 => PerpetualUID) internal perpetualUIDs;
    mapping(bytes32 => EnumerableSetUpgradeable.UintSet) internal perpetualSymbols;
    uint256 private _nextSymbol;
    uint256 internal constant RESERVED_SYMBOL_COUNT = 10000;
    EnumerableSetUpgradeable.AddressSet  private _liquidityPoolFactories;
    
    event AssignSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol);

    constructor(address factory) OwnableUpgradeable() {
        _nextSymbol = RESERVED_SYMBOL_COUNT;
        _liquidityPoolFactories.add(factory);
    }

    function getPerpetualUID(uint256 symbol) public view returns (PerpetualUID memory perpetualUID) {
        perpetualUID = perpetualUIDs[symbol];
        require(perpetualUID.liquidityPool != address(0), "symbol not found");
    }

    function getSymbol(PerpetualUID memory perpetualUID) public view returns (uint256[] memory symbols) {
        bytes32 key = _poolPerpetualKey(perpetualUID);
        uint256 len = perpetualSymbols[key].length();
        symbols = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            symbols[i] = perpetualSymbols[key].at(i);
        }
    }
    
    function assignNormal(PerpetualUID memory perpetualUID) public returns (uint256 symbol) {
        require(AddressUpgradeable.isContract(msg.sender), "must called by contract");
        (address[6] memory addresses, , ,) = ILiquidityPool(msg.sender).liquidityPoolInfo();
        require(_liquidityPoolFactories.contains(addresses[0]), "wrong factory");
        require(_nextSymbol <= type(uint256).max, "not enough symbol");
        
        bytes32 key = _poolPerpetualKey(perpetualUID);
        require(perpetualSymbols[key].length() == 0, "perpetual already exists");
        addPerpetualUID(perpetualUID, _nextSymbol, key);
        symbol = _nextSymbol;
        _nextSymbol = _nextSymbol + 1;
    }

    function assignSpecial(PerpetualUID memory perpetualUID, uint256 symbol) public onlyOwner {
        require(symbol < RESERVED_SYMBOL_COUNT, "symbol overflow");
        require(perpetualUIDs[symbol].liquidityPool == address(0), "symbol already exists");
        bytes32 key = _poolPerpetualKey(perpetualUID);
        require(perpetualSymbols[key].length() == 1 && perpetualSymbols[key].at(0) >= RESERVED_SYMBOL_COUNT, "special perpetual already exists");
        addPerpetualUID(perpetualUID, symbol, key);
    }
    
    function addPerpetualUID(PerpetualUID memory perpetualUID, uint256 symbol, bytes32 key) internal {
        perpetualUIDs[symbol] = perpetualUID;
        perpetualSymbols[key].add(symbol);
        emit AssignSymbol(perpetualUID.liquidityPool, perpetualUID.perpetualIndex, symbol);
    }
    
    function _poolPerpetualKey(PerpetualUID memory perpetualUID)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(perpetualUID.liquidityPool, perpetualUID.perpetualIndex));
    }
    
    function addFactory(address factory) public onlyOwner returns (bool) {
        return _liquidityPoolFactories.add(factory);
    }
    
    function removeFactory(address factory) public onlyOwner returns (bool) {
        return _liquidityPoolFactories.remove(factory);
    }

}