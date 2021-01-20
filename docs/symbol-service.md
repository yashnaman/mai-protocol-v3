# Symbol service

A perpetual can have one unreserved symbol or two symbols: one unreserved symbol and one reserved symbol.

## Unreserved symbol

When a perpetual is created, it will be allocated an unreserved symbol. Unreserved symbol starts with the number of reserved symbols. And it's added one after each allocation. The allocation will fail if the perpetual has symbol before.

The implementation of the function is:
```solidity
allocateSymbol(address liquidityPool, uint256 perpetualIndex)
```

## Reserved symbol

Reserved symbol must be less than the number of reserved symbols. If the perpetual wants to have a reserved symbol, it must have one unreserved symbol and have no reserved symbol before. The governor can assign it a reserved symbol through function:
```solidity
assignReservedSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol)
```
