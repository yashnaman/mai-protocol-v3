# Trade details

## General process

1. Validation.
2. AMM calculates trading price.
3. Update trader's account and AMM's account.
4. Transfer fee.
5. Safety check.

## Requirements

1. Sender is granted trade privilege by trader if sender is not trader.
2. Trade didn't exceed deadline.
3. Perpetual's oracle is not paused and its state is "NORMAL".
4. If order type is close-only, stop-loss and take-profit, trading amount will be limited to close trader's position. And it can't be zero.
5. AMM allows the trade.(Details of AMM are in amm.md)
6. If order type is not market, trading price must better than the limit price.
7. Trader's account must be initial margin safe after the trade if opening position, must be margin safe after the trade if closing position.

# Liquidate details

If an account is not maintenance margin safe in perpetual. It can be liquidated by any other account. The max liquidate amount is his position amount. There are two types of liquidation.

## Liquidate by AMM

AMM takes the all position as possible(if the amount is too large, AMM may not take all the position, please see amm.md).

The liquidate price is determied by AMM like a normal trade(there is a little difference, please see amm.md).

The sender only gets the keeper gas reward.

Penalty is calculated as `abs(liquidate amount) * mark price * liquidation penalty rate`. Defined trader's **partial margin** as `margin * abs(liquidate amount) / abs(position amount)`.
- If trader's partial margin is more than penalty, `penalty * insurance fund rate` will be transferred to perpetual's insurance fund. The rest will be transferred to AMM's account. In other words, it belongs to liquidity provider.
- If trader's partial margin is positive and less than penalty, penalty is change to trader's margin and the rest steps are the same.
- If trader's partial margin is negative, there is no penalty and insurance fund of perpetual will cover the loss to change trader's partial margin to zero. If the insurance fund including the donated part is negative, the perpetual's state will enter "EMERGENCY".

## Liquidate by Liquidator(another trader)

Liquidator takes the position. Liquidator will specify position amount and limit price.

The liquidate price is mark price and must better than limit price. 

Penalty is calculated as `abs(liquidate amount) * mark price * liquidation penalty rate`. Defined trader's **partial margin** as `margin * abs(liquidate amount) / abs(position amount)`.
- If trader's partial margin is more than penalty, `penalty * insurance fund rate` will be transferred to perpetual's insurance fund. The rest will be transferred to liquidator.
- If trader's partial margin is positive and less than penalty, penalty is change to trader's partial margin and the rest steps are the same.
- If trader's partial margin is negative, there is no penalty and insurance fund of perpetual will cover the loss to change trader's partial margin to zero. If the insurance fund including the donated part is negative, the perpetual's state will enter "EMERGENCY".

# Settle details

There are two cases will make the perpetual begin to settle:
1. The account of AMM in the perpetual is not maintenance margin safe
2. The insurance fund's collateral of perpetual including the donated part is negative

## Process

1. The state of the perpetual change from "NORMAL" to "EMERGENCY".
2. Clear active accounts in the perpetual one by one.
3. After all active accounts are cleared, the state of the perpetual change from "EMERGENCY" to "CLEARED".
4. Every account in the perpetual can be settled and get the collateral back to wallet.
