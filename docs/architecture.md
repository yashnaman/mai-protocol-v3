# Architecture

The Mai Protocol V3 is mainly composed of five parts: Pool Creator, Liquidity Pool, Perpetual, AMM and Governor. The Pool Creator manages the liquidity pools. The Liquidity Pool holds the liquidity and can contain multiple perpetuals. The Perpetual stores the data of margin accounts of the traders. The AMM is the counterparty of the traders. The Governor has the highest authority of the liquidity pool.

![mai3-arch](asset/mai3-arch.png)

## Pool Creator

Pool Creator manages the liquidity pools. It stores the different versions of the liquidity pool implementations. The operator can create new liquidity pool of the specific version through it. Trader can grant or revoke the other trader privilege(deposit / withdraw / trade) through Pool Creator.

## Liquidity Pool

The Liquidity Pool holds the liquidity. The traders can add or remove liquidity through it. A liquidity pool can have multiple perpetuals with the same collateral, which means these perpetuals have the shared liquidity.

## Perpetual

The Perpetual stores the data of margin accounts of the traders. The trader can deposit / withdraw / trade in the perpetual. The multiple perpetuals in the same liquidity pool can have different underlying assets and oracles, but they must have the same collateral.

## AMM

The AMM is the counterparty of the traders. One liquidity pool has one AMM. It offers the trading price when trading and determines the funding rate. AMM also calculates how many share tokens to mint when adding liquidity and how many collateral to return when removing liquidity. Trading and removing liquidity will be forbidden by AMM in some cases.

## Governor

The Governor has the highest authority of the liquidity pool. The liquidity provider can propose proposal and vote. If the proposal is passed, the actions in the proposal will be executed by the Governor.