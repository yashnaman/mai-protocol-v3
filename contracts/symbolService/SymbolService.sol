// SPDX-License-Identifier: None

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface ILiquidityPool {
    function getLiquidityPoolInfo()
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

    event AllocateSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol);
    event AddWhitelistedFactory(address factory);
    event RemoveWhitelistedFactory(address factory);

    constructor(uint256 reservedSymbolCount) Ownable() {
        _nextSymbol = reservedSymbolCount;
        _reservedSymbolCount = reservedSymbolCount;
    }

    function isWhitelistedFactory(address factory) public view returns (bool) {
        return _whitelistedFactories.contains(factory);
    }

    function addWhitelistedFactory(address factory) public onlyOwner {
        require(!isWhitelistedFactory(factory), "factory already exists");
        _whitelistedFactories.add(factory);
        emit AddWhitelistedFactory(factory);
    }

    function removeWhitelistedFactory(address factory) public onlyOwner {
        require(isWhitelistedFactory(factory), "factory not found");
        _whitelistedFactories.remove(factory);
        emit RemoveWhitelistedFactory(factory);
    }

    modifier onlyWhitelisted(address liquidityPool) {
        require(Address.isContract(liquidityPool), "must called by contract");
        (address[6] memory addresses, , , ) = ILiquidityPool(liquidityPool).getLiquidityPoolInfo();
        require(_whitelistedFactories.contains(addresses[0]), "wrong factory");
        _;
    }

    function getPerpetualUID(uint256 symbol)
        public
        view
        returns (address liquidityPool, uint256 perpetualIndex)
    {
        PerpetualUID storage perpetualUID = _perpetualUIDs[symbol];
        require(perpetualUID.liquidityPool != address(0), "symbol not found");
        liquidityPool = perpetualUID.liquidityPool;
        perpetualIndex = perpetualUID.perpetualIndex;
    }

    function getSymbols(address liquidityPool, uint256 perpetualIndex)
        public
        view
        returns (uint256[] memory symbols)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        uint256 length = _perpetualSymbols[key].length();
        if (length == 0) {
            return symbols;
        }
        symbols = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            symbols[i] = _perpetualSymbols[key].at(i);
        }
    }

    function allocateSymbol(address liquidityPool, uint256 perpetualIndex)
        public
        onlyWhitelisted(msg.sender)
        returns (uint256 symbol)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(_perpetualSymbols[key].length() == 0, "perpetual already exists");

        symbol = _nextSymbol;
        require(symbol < type(uint256).max, "not enough symbol");
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        _nextSymbol = _nextSymbol + 1;
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    function assignReservedSymbol(
        address liquidityPool,
        uint256 perpetualIndex,
        uint256 symbol
    ) public onlyOwner onlyWhitelisted(liquidityPool) {
        require(symbol < _reservedSymbolCount, "symbol exceeds reserved symbol count");
        require(_perpetualUIDs[symbol].liquidityPool == address(0), "symbol already exists");

        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(
            _perpetualSymbols[key].length() == 1 &&
                _perpetualSymbols[key].at(0) >= _reservedSymbolCount,
            "perpetual must have normal symbol and mustn't have reversed symbol"
        );
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    function _getPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}
