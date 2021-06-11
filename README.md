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

The smart contracts were audited by quantstamp: [MCDEX Audit Report](https://certificate.quantstamp.com/full/mcdex).

## Deployed Contracts

### Arbitrum Rinkeby Testnet

|Contract|Description|Address|
|---|---|---|
|[`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to PoolCreator |[0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834](https://rinkeby-explorer.arbitrum.io/address/0x0A1334aCea4E38a746daC7DCf7C3E61F0AB3D834)|
|[`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol) |PoolCreator manages the liquidity pools and global variables. |[0x18aA2A2D5643d6FbA57A2FCCdFC116694D318Be6](https://rinkeby-explorer.arbitrum.io/address/0x18aA2A2D5643d6FbA57A2FCCdFC116694D318Be6)|
|[`SymbolService`](contracts/symbolService/SymbolService.sol) |Provide a shorter symbol for each perpetuals |[0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22](https://rinkeby-explorer.arbitrum.io/address/0xA4109D0a36E0e66d64F3B7794C60694Ca6D66E22)|
|[`Broker`](contracts/broker/Broker.sol) |A relay to execute pre-signed transactions |[0xC9010d5B798286651dC24A2c49BbAd673Dd4978b](https://rinkeby-explorer.arbitrum.io/address/0xC9010d5B798286651dC24A2c49BbAd673Dd4978b)|
|[`Reader`](contracts/reader/Reader.sol) |A tool to read status of liquidity pool |[0x25E74e6D8A414Dff02c9CCC680B49F3708955ECF](https://rinkeby-explorer.arbitrum.io/address/0x25E74e6D8A414Dff02c9CCC680B49F3708955ECF)|
|[`LiquidityPool (implementation)`](contracts/LiquidityPool.sol) |A liquidity pool provides liquidity for multiple perpetuals using the same collateral |[0x957795c3C7e7717BCcb4B5F16058f5455d08247A](https://rinkeby-explorer.arbitrum.io/address/0x957795c3C7e7717BCcb4B5F16058f5455d08247A)|
|[`LpGovernor (implementation)`](contracts/LiquidityPool.sol) |Share token and governance functions |[0x01C7f850C135a4998C0BEfC5a106037D67b77619](https://rinkeby-explorer.arbitrum.io/address/0x01C7f850C135a4998C0BEfC5a106037D67b77619)|


### Arbitrum One Mainnet

|Contract|Description|Address|
|---|---|---|
|[`PoolCreator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to PoolCreator |[0x133906776302D10A2005ec2eD0C92ab6F2cbd903](https://mainnet-arb-explorer.netlify.app/address/0x133906776302D10A2005ec2eD0C92ab6F2cbd903)|
|[`PoolCreator (implementation)`](contracts/factory/PoolCreator.sol) |PoolCreator manages the liquidity pools and global variables. |[0x09039a7593396687bA58e3a8BB8DD1FF94e3634E](https://mainnet-arb-explorer.netlify.app/address/0x09039a7593396687bA58e3a8BB8DD1FF94e3634E)|
|[`SymbolService`](contracts/symbolService/SymbolService.sol) |Provide a shorter symbol for each perpetuals |[0xb95B9fb0539Ec84DeD2855Ed1C9C686Af9A4e8b3](https://mainnet-arb-explorer.netlify.app/address/0xb95B9fb0539Ec84DeD2855Ed1C9C686Af9A4e8b3)|
|[`Broker`](contracts/broker/Broker.sol) |A relay to execute pre-signed transactions |[0xE0245D11D58a4Cb60687766B9ADe4eEd1dd66B2B](https://mainnet-arb-explorer.netlify.app/address/0xE0245D11D58a4Cb60687766B9ADe4eEd1dd66B2B)|
|[`Reader`](contracts/reader/Reader.sol) |A tool to read status of liquidity pool |[0xD6a78B45caA10Ee3b6b4906D687f0E46dE89f0e2](https://mainnet-arb-explorer.netlify.app/address/0xD6a78B45caA10Ee3b6b4906D687f0E46dE89f0e2)|
|[`LiquidityPool (implementation)`](contracts/LiquidityPool.sol) |A liquidity pool provides liquidity for multiple perpetuals using the same collateral |[0xED064e2Dc0aE28517b9842b4b3116dc0B0def932](https://mainnet-arb-explorer.netlify.app/address/0xED064e2Dc0aE28517b9842b4b3116dc0B0def932)|
|[`LpGovernor (implementation)`](contracts/LiquidityPool.sol) |Share token and governance functions |[0x0BE26Df6Bb17BE88E5816B9c05361d6340e409a7](https://mainnet-arb-explorer.netlify.app/address/0x0BE26Df6Bb17BE88E5816B9c05361d6340e409a7)|

## Development
### Compile contracts
```
npm install
npx hardhat compile
npx hardhat run scripts/s10test.ts
```
