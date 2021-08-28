# mai-protocol-v3

> Mai Protocol V3 designed by MCDEX is an AMM-based decentralized perpetual swap protocol. Perpetual swap is one of the most popular derivatives that has no expiration date, supports margin trading, and has its price soft pegged to index price.
>
> The name Mai comes from two Chinese characters "买" which means buy and "卖" which means sell. Using pinyin (the modern system for transliterating Chinese characters to Latin letters) "买" is spelled Mǎi and "卖" is spelled Mài. Thus, "Mai" means "Buy" and "Sell".

**If not specified in advance, we always use decimals 18 as default in the code and documents.**

## Overview

[Overview](./contracts/Readme.md) of mai-protocol-v3.

## Reference

[Terms](./docs/term.md)

[References](https://mcdex.io/references/)

[AMMDesign](https://mcdexio.github.io/documents/en/Shared-Liquidity-AMM-of-MAI-PROTOCOL-v3.pdf)

## Audit

The smart contracts were audited by quantstamp:

- [Audit1: MCDEX Audit Report](./docs/asset/audit1-Quantstamp-MCDEX.pdf).
- [Audit2: MCDEX Audit Report](./docs/asset/audit2-Quantstamp-MCDEX-Arbitrum-Integration-Report.pdf).

## Deployed Contracts

### Arbitrum Rinkeby Testnet

| Contract                                                                                                                                    | Description                                                                           | Address                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| [`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) | A proxy to PoolCreator                                                                | [0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834](https://rinkeby-explorer.arbitrum.io/address/0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834) |
| [`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol)                                                                         | PoolCreator manages the liquidity pools and global variables.                         | [0xe3DeCcd76ea1A0F7C7d4A80AD0A790dC00c0578E](https://rinkeby-explorer.arbitrum.io/address/0xe3DeCcd76ea1A0F7C7d4A80AD0A790dC00c0578E) |
| [`SymbolService`](contracts/symbolService/SymbolService.sol)                                                                                | Provide a shorter symbol for each perpetuals                                          | [0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22](https://rinkeby-explorer.arbitrum.io/address/0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22) |
| [`Broker`](contracts/broker/Broker.sol)                                                                                                     | A relay to execute pre-signed transactions                                            | [0xC9010d5B798286651dC24A2c49BbAd673Dd4978b](https://rinkeby-explorer.arbitrum.io/address/0xC9010d5B798286651dC24A2c49BbAd673Dd4978b) |
| [`Reader`](contracts/reader/Reader.sol)                                                                                                     | A tool to read status of liquidity pool                                               | [0x49354B337395dB4d23F71a1f74E080A10a6AcF0C](https://rinkeby-explorer.arbitrum.io/address/0x49354B337395dB4d23F71a1f74E080A10a6AcF0C) |
| [`OracleRouterCreator`](contracts/oracle/router/OracleRouterCreator.sol)                                                                    | An Oracle who provides prices according to a path of multiple Oracles.                | [0x9730DD5a6eb170082c7c71c2e41332853681bb92](https://rinkeby-explorer.arbitrum.io/address/0x9730DD5a6eb170082c7c71c2e41332853681bb92) |
| [`UniswapV3OracleAdaptorCreator`](contracts/oracle/uniswap/UniswapV3OracleAdaptorCreator.sol)                                               | An Oracle who provides prices according to Uniswap v3.                                | [0x6154996e1C80dE982f9eebC3E93B4DFd4F30a74a](https://rinkeby-explorer.arbitrum.io/address/0x6154996e1C80dE982f9eebC3E93B4DFd4F30a74a) |
| [`InverseStateService`](contracts/inverse/InverseStateService.sol)                                                                          | Let an Operator mark a Perpetual as an inverse Perpetual.                             | [0xc4F97bD99f10Ca08Ce9ec9C9CB05C72F358dbC5E](https://rinkeby-explorer.arbitrum.io/address/0xc4F97bD99f10Ca08Ce9ec9C9CB05C72F358dbC5E) |
| [`LiquidityPool (implementation)`](contracts/LiquidityPool.sol)                                                                             | A liquidity pool provides liquidity for multiple perpetuals using the same collateral | [0xfA26d63b1db58d08800053180Db11245Eb7f102f](https://rinkeby-explorer.arbitrum.io/address/0xfA26d63b1db58d08800053180Db11245Eb7f102f) |
| [`LpGovernor (implementation)`](contracts/LiquidityPool.sol)                                                                                | Share token and governance functions                                                  | [0xaFeB8BCd2291ff55Cf37876c8dcD7154e0e228a7](https://rinkeby-explorer.arbitrum.io/address/0xaFeB8BCd2291ff55Cf37876c8dcD7154e0e228a7) |

### Arbitrum One Mainnet


| Contract                                                     | Description                                                  | Address                                                      |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| [`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) | A proxy to PoolCreator                                       | [0xA017B813652b93a0aF2887913EFCBB4ab250CE65](https://explorer.offchainlabs.com/address/0xA017B813652b93a0aF2887913EFCBB4ab250CE65) |
| [`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol) | PoolCreator manages the liquidity pools and global variables. | [0x592c6A6419fB86BAD15926c840A9f9306f69f590](https://explorer.offchainlabs.com/address/0x592c6A6419fB86BAD15926c840A9f9306f69f590) |
| [`SymbolService (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) | A proxy to SymbolService                                     | [0x2842c57C2736BB459BdAc97bAA22596e71f05811](https://explorer.offchainlabs.com/address/0x2842c57C2736BB459BdAc97bAA22596e71f05811) |
| [`SymbolService (implementation)`](contracts/symbolService/SymbolService.sol) | Provide a shorter symbol for each perpetuals                 | [0xe9B15e490C193324d699CdA062c54E13d81A035c](https://explorer.offchainlabs.com/address/0xe9B15e490C193324d699CdA062c54E13d81A035c) |
| [`Broker`](contracts/broker/Broker.sol)                      | A relay to execute pre-signed transactions                   | [0xf985cA33B8b787599DE77E4Ccf2d0Ecbf27d87d9](https://explorer.offchainlabs.com/address/0xf985cA33B8b787599DE77E4Ccf2d0Ecbf27d87d9) |
| [`Reader`](contracts/reader/Reader.sol)                      | A tool to read status of liquidity pool                      | [0x708C17D0901B76cc5CF8F67e1a2E198077FD8641](https://explorer.offchainlabs.com/address/0x708C17D0901B76cc5CF8F67e1a2E198077FD8641) |
| [`OracleRouterCreator`](contracts/oracle/router/OracleRouterCreator.sol) | An Oracle who provides prices according to a path of multiple Oracles. | [0xC3E272F76b3740C2AcF8e5272CbEF06D70e14FF3](https://explorer.offchainlabs.com/address/0xC3E272F76b3740C2AcF8e5272CbEF06D70e14FF3) |
| [`UniswapV3OracleAdaptorCreator`](contracts/oracle/uniswap/UniswapV3OracleAdaptorCreator.sol) | An Oracle who provides prices according to Uniswap v3.       | [0xCEda10b4d3bdE429DdA3A6daB87b38360313CBdB](https://explorer.offchainlabs.com/address/0xCEda10b4d3bdE429DdA3A6daB87b38360313CBdB) |
| [`InverseStateService`](contracts/inverse/InverseStateService.sol) | Let an Operator mark a Perpetual as an inverse Perpetual.    | [0x129AD040Bd127c00d6De9051b3CfE9F3E36453D3](https://explorer.offchainlabs.com/address/0x129AD040Bd127c00d6De9051b3CfE9F3E36453D3) |
| [`LiquidityPool (implementation)`](contracts/LiquidityPool.sol) | A liquidity pool provides liquidity for multiple perpetuals using the same collateral | [0xEf5D601ea784ABd465c788C431d990b620e5Fee6](https://explorer.offchainlabs.com/address/0xEf5D601ea784ABd465c788C431d990b620e5Fee6) |
| [`LpGovernor (implementation)`](contracts/LiquidityPool.sol) | Share token and governance functions                         | [0x2Baac806CB2b7A07f8f73DB1329767E5a3CbDF4e](https://explorer.offchainlabs.com/address/0x2Baac806CB2b7A07f8f73DB1329767E5a3CbDF4e) |

## Development

### Compile contracts

```
npm install
npx hardhat compile
npx hardhat run scripts/s10test.ts
```
