# Fee

## Trade

| Fee          | Belong to          | How to calculate               | Note                          |
|--------------|--------------------|--------------------------------|-------------------------------|
| lp fee       | liquidity provider | tradeValue * lp fee rate       | may rebate a part to referral |
| operator fee | operator           | tradeValue * operator fee rate | may rebate a part to referral |
| vault fee    | vault              | tradeValue * vault fee rate    |                               |

### What if trader's available margin is not enough to pay fee

Trader is not allowed to open position in this case.

If trader is closing position:

- If `available margin ≤ 0`, all three fees are zero.
- If `0 < available margin < lp fee + operator fee + vault fee`, three fees split available margin proportionally.

### What if there is a referrer in trade

Lp fee and operator fee will rebate a part to referrer.

`referral rebate = (lp fee + operator fee) * referral rebate rate`

`lp fee = lp fee * (1 - referral rebate rate)`

`operator fee = operator fee * (1 - referral rebate rate)`

## Liquidate

There is no fee in both two types of liquidation.