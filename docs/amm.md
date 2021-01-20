# AMM details

The AMM is the counterparty of the traders. One liquidity pool has one AMM. It offers the trading price when trading and determines the funding rate. AMM also calculates how many share tokens to mint when adding liquidity and how many collateral to return when removing liquidity.

## Margin

AMM has shared liquidity in multiple perpetuals. So the margin of AMM is different from normal trader. Which defined as:

pool cash + margin in perpetual1 + margin in perpetual2 + ...

## Pool margin

Margin is not accurate to indicate how much liquidity of AMM is when AMM has position. Because if AMM closes position, the trading price is offered by itself, not mark price. So we define the liquidity of AMM as the collateral of AMM if AMM closes all position at the price offered by itself. Which named as pool margin. The formula is formula (8) in amm.pdf. The implementation function of formula is:

```solidity
calculatePoolMarginWhenSafe(Context memory context, int256 slippageFactor)
```

## Is safe

If AMM has too much loss, pool margin may can't be calculated. We define AMM is unsafe in this case. The formula of checking if AMM is safe is formula (31) in amm.pdf. The implementation function of formula is:

```solidity
isAMMSafe(Context memory context, int256 slippageFactor)
```

If AMM is not safe, pool margin is defined as 0.5 * margin. The function to get pool margin whether safe or not is:

```solidity
getPoolMargin(Context memory context)
```

## Trade

The trade will be divided into two parts: AMM closes its position and AMM opens its position. If the trading price of the whole trade is better than speard price for trader, clip the trading price to spread price. Spread price is middle price offered by AMM * (1 +/- half spread). The formula of middle price is formula (11) in amm.pdf. The implementation function of formula is:

```solidity
_getMidPrice(int256 poolMargin, int256 indexPrice, int256 position, int256 slippageFactor)
```

### AMM closes position

Trade will always success if AMM is closing position.

If AMM is unsafe, trading price is index price in normal case or (1 - max close price discount) * index price in special case. Special case means position > 0 and close slippage factor > 0.5.

If AMM is safe, the formula of trading price is formula (7) in amm.pdf. The implementation function of formula is:

```solidity
_getDeltaCash(int256 poolMargin, int256 positionBefore, int256 positionAfter, int256 indexPrice, int256 slippageFactor)
```

This function returns the update cash amount of AMM after trade, divide by position amount to get the trading price. If the trading price is too bad for AMM, limit the trading price to index price * (1 +/- max close price discount).

The whole function of AMM closing position is:

```solidity
ammClosePosition(Context memory context, PerpetualStorage storage perpetual, int256 tradeAmount)
```

### AMM opens position

Trade is not allowed if AMM is unsafe.

If AMM is safe, AMM can't trade to exceed its maximum position. Maximum position of AMM is calculated by three restrictions:
1. AMM must offer positive price in any perpetual after the trade. Which means: pool margin <= (index price * position * open slippage factor) in any perpetual. It's easy to prove that, in the perpetual, AMM definitely offers positive price when AMM holds short position.
2. AMM mustn't exceed maximum leverage in any perpetual after the trade. Which means: margin <= (position * index price / maximum leverage) in perpetual1 + (position * index price / max leverage) in perpetual2 + ...
3. AMM must be safe after the trade.

The formula of calculating maximum position of AMM is in appendix 3 in amm.pdf. The implementation function of formula is:

```solidity
_getMaxPosition(Context memory context, int256 poolMargin, int256 ammMaxLeverage, int256 slippageFactor, bool isLongSide)
```

If allowed partial fill(liquidate trade) and AMM will exceed its maximum position after trade, trade amount will be executed a part. AMM actually reaches its maximum position after trade.

If not allowed partial fill(normal trade) and AMM will exceed its maximum position after trade, the trade will be reverted.

The formula of trading price and the implementation function are the same as closing position.

The whole function of AMM opening position is:

```solidity
ammOpenPosition(Context memory context, PerpetualStorage storage perpetual, int256 tradeAmount, bool partialFill)
```

## Add liquidity

AMM will calculate how much share token to mint when liquidity provider adds liquidity to liquidity pool. The principle is to keep pool margin / share token unchanged after adding liquidity. The formula is formula (18) in amm.pdf. The implementation function of formula is:

```solidity
getShareToMint(LiquidityPoolStorage storage liquidityPool, int256 shareTotalSupply, int256 cashToAdd)
```

## Remove liquidity
AMM will calculate how much collateral to return when liquidity provider removes liquidity from liquidity pool. The principle is the same with adding liquidity, to keep pool margin / share token unchanged after removing liquidity. The formula is formula (19) in amm.pdf. The implementation function of formula is:

```solidity
getCashToReturn(LiquidityPoolStorage storage liquidityPool, int256 shareTotalSupply, int256 shareToRemove)
```

Removing liquidity is forbidden at several cases:
1. AMM is unsafe before removing liquidity.
2. AMM is unsafe after removing liquidity.
3. AMM will offer negative price at any perpetual after removing liquidity. Which means: pool margin <= (index price * position * open slippage factor) in any perpetual
4. AMM will exceed maximum leverage at any perpetual after removing liquidity. Which means: margin <= (position * index price / maximum leverage) in perpetual1 + (position * index price / max leverage) in perpetual2 + ...
