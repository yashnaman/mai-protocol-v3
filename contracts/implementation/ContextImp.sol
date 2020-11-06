// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";
import "./MarginAccountImp.sol";

library ContextImp {

    using MarginAccountImp for Perpetual;

    function makeContext(
        Perpetual storage perpetual,
        address taker,
        address maker
    ) internal view returns (Context memory) {
        // update account
        Context memory context;
        context.taker = taker;
        context.maker = maker;
        context.takerAccount = perpetual.traderAccounts[taker];
        context.makerAccount = perpetual.traderAccounts[maker];
    }

    function commit(Perpetual storage perpetual, Context memory context) internal {
        // update account
        perpetual.traderAccounts[context.taker] = context.takerAccount;
        perpetual.traderAccounts[context.maker] = context.makerAccount;
        // fee
        // perpetual.lpFee;
        // perpetual.vaultFee;
        // perpetual.operatorFee;
        // perpetual.tradingPrice;
    }

}