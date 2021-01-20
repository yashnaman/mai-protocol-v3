# Mai Protocol V3 Term

## Liquidity pool

A pool with collateral, can have multiple perpetuals. These perpetuals have the same type of collateral.

## Perpetual

A market where trader can trade / deposit / withdraw, has collateral and underlying asset. Stored accounts of all traders.

## Index price

Price of underlying asset in perpetual. Offered by oracle. Used to help AMM calculating.

## Mark price

Price of underlying asset in perpetual. Offered by oracle. Used to calculate account data.

## Account

**Cash** and **position** of a trader in perpetual, both values can be negative.

## Available cash

`cash - position * unit accumulative funding`. The cash which counted funding payment.

## Margin

`available cash + mark price * position`. The margin of an account in perpetual considering position.

## Initial margin

`mark price * abs(position) * initial margin rate`. The used margin of an account in perpetual.

## Maintenance margin

`mark price * abs(position) * maintenance margin rate`. The maintenance margin of an account in perpetual.

## Available margin

- If position = 0: `cash`
- If position != 0: `margin - max(initial margin, keeper gas reward)`

The available margin of an account in perpetual.

## Initial margin safe

`available margin >= 0`

## Maintenance margin safe

- If position = 0: `cash >= 0`
- If position != 0: `margin >= max(maintenance margin, keeper gas reward)`

## Margin safe

- If position = 0: `cash >= 0`
- If position != 0: `margin >= keeper gas reward`
