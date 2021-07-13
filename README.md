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
* [Audit1: MCDEX Audit Report](./docs/asset/audit1-Quantstamp-MCDEX.pdf).
* [Audit2: MCDEX Audit Report](./docs/asset/audit2-Quantstamp-MCDEX-Arbitrum-Integration-Report.pdf).

## Deployed Contracts

### Arbitrum Rinkeby Testnet

|Contract|Description|Address|
|---|---|---|
|[`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to PoolCreator |[0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834](https://rinkeby-explorer.arbitrum.io/address/0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834)|
|[`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol) |PoolCreator manages the liquidity pools and global variables. |[0xe3DeCcd76ea1A0F7C7d4A80AD0A790dC00c0578E](https://rinkeby-explorer.arbitrum.io/address/0xe3DeCcd76ea1A0F7C7d4A80AD0A790dC00c0578E)|
|[`SymbolService`](contracts/symbolService/SymbolService.sol) |Provide a shorter symbol for each perpetuals |[0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22](https://rinkeby-explorer.arbitrum.io/address/0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22)|
|[`Broker`](contracts/broker/Broker.sol) |A relay to execute pre-signed transactions |[0xC9010d5B798286651dC24A2c49BbAd673Dd4978b](https://rinkeby-explorer.arbitrum.io/address/0xC9010d5B798286651dC24A2c49BbAd673Dd4978b)|
|[`Reader`](contracts/reader/Reader.sol) |A tool to read status of liquidity pool |[0x62580b94815BC879Fda6210Bd12f1f58d259Af5d](https://rinkeby-explorer.arbitrum.io/address/0x62580b94815BC879Fda6210Bd12f1f58d259Af5d)|
|[`OracleRouterCreator`](contracts/oracle/router/OracleRouterCreator.sol) |An Oracle who provides prices according to a path of multiple Oracles. |[0x9730DD5a6eb170082c7c71c2e41332853681bb92](https://rinkeby-explorer.arbitrum.io/address/0x9730DD5a6eb170082c7c71c2e41332853681bb92)|
|[`UniswapV3OracleAdaptorCreator`](contracts/oracle/uniswap/UniswapV3OracleAdaptorCreator.sol) |An Oracle who provides prices according to Uniswap v3. |[0x6154996e1C80dE982f9eebC3E93B4DFd4F30a74a](https://rinkeby-explorer.arbitrum.io/address/0x6154996e1C80dE982f9eebC3E93B4DFd4F30a74a)|
|[`InverseStateService`](contracts/inverse/InverseStateService.sol) |Let an Operator mark a Perpetual as an inverse Perpetual. |[0xc4F97bD99f10Ca08Ce9ec9C9CB05C72F358dbC5E](https://rinkeby-explorer.arbitrum.io/address/0xc4F97bD99f10Ca08Ce9ec9C9CB05C72F358dbC5E)|
|[`LiquidityPool (implementation)`](contracts/LiquidityPool.sol) |A liquidity pool provides liquidity for multiple perpetuals using the same collateral |[0xfA26d63b1db58d08800053180Db11245Eb7f102f](https://rinkeby-explorer.arbitrum.io/address/0xfA26d63b1db58d08800053180Db11245Eb7f102f)|
|[`LpGovernor (implementation)`](contracts/LiquidityPool.sol) |Share token and governance functions |[0xaFeB8BCd2291ff55Cf37876c8dcD7154e0e228a7](https://rinkeby-explorer.arbitrum.io/address/0xaFeB8BCd2291ff55Cf37876c8dcD7154e0e228a7)|


### Arbitrum One Mainnet

|Contract|Description|Address|
|---|---|---|
|[`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to PoolCreator |[0x784819cbA91Ed87C296565274fc150EaA11EBC04](https://explorer.offchainlabs.com/address/0x784819cbA91Ed87C296565274fc150EaA11EBC04)|
|[`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol) |PoolCreator manages the liquidity pools and global variables. |[0xd18dEf50FdAEA4cBf14aCBc82c30D2b40EFFA12E](https://explorer.offchainlabs.com/address/0xd18dEf50FdAEA4cBf14aCBc82c30D2b40EFFA12E)|
|[`SymbolService (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to SymbolService |[0x7863913067024e11249Da20B71d453164d4Dea7D](https://explorer.offchainlabs.com/address/0x7863913067024e11249Da20B71d453164d4Dea7D)|
|[`SymbolService (implementation)`](contracts/symbolService/SymbolService.sol) |Provide a shorter symbol for each perpetuals |[0xc849a41bc49407dE53eC206eaDCC2924Dccb9aaF](https://explorer.offchainlabs.com/address/0xc849a41bc49407dE53eC206eaDCC2924Dccb9aaF)|
|[`Broker`](contracts/broker/Broker.sol) |A relay to execute pre-signed transactions |[0x3D782bBa1c2568E33ba5a20a9Ddf3879BBf136c0](https://explorer.offchainlabs.com/address/0x3D782bBa1c2568E33ba5a20a9Ddf3879BBf136c0)|
|[`Reader`](contracts/reader/Reader.sol) |A tool to read status of liquidity pool |[0x3d4B40cA0F98fcCe38aA1704CBDf134496c261E8](https://explorer.offchainlabs.com/address/0x3d4B40cA0F98fcCe38aA1704CBDf134496c261E8)|
|[`OracleRouterCreator`](contracts/oracle/router/OracleRouterCreator.sol) |An Oracle who provides prices according to a path of multiple Oracles. |[0x5378B0388Ef594f0c2EB194504aee2B48d1eac18](https://explorer.offchainlabs.com/address/0x5378B0388Ef594f0c2EB194504aee2B48d1eac18)|
|[`UniswapV3OracleAdaptorCreator`](contracts/oracle/uniswap/UniswapV3OracleAdaptorCreator.sol) |An Oracle who provides prices according to Uniswap v3. |[0xe2F6FB9C2f78Bcf9dacDF76Bd0e7Fad4E4b1794a](https://explorer.offchainlabs.com/address/0xe2F6FB9C2f78Bcf9dacDF76Bd0e7Fad4E4b1794a)|
|[`InverseStateService`](contracts/inverse/InverseStateService.sol) |Let an Operator mark a Perpetual as an inverse Perpetual. |[0x9A01AEfe70B2Fbe4458B86136B2EEFEfb8Bc8DB4](https://explorer.offchainlabs.com/address/0x9A01AEfe70B2Fbe4458B86136B2EEFEfb8Bc8DB4)|
|[`LiquidityPool (implementation)`](contracts/LiquidityPool.sol) |A liquidity pool provides liquidity for multiple perpetuals using the same collateral |[0x8a11427B22Ca86a55969FAa93A3a9B0F7b2eebD0](https://explorer.offchainlabs.com/address/0x8a11427B22Ca86a55969FAa93A3a9B0F7b2eebD0)|
|[`LpGovernor (implementation)`](contracts/LiquidityPool.sol) |Share token and governance functions |[0xf7F85A5F62eD2Eb63C8D4EDF0a979289857Bad74](https://explorer.offchainlabs.com/address/0xf7F85A5F62eD2Eb63C8D4EDF0a979289857Bad74)|

## Development
### Compile contracts
```
npm install
npx hardhat compile
npx hardhat run scripts/s10test.ts
```
