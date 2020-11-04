// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

library ContextImp {

    function commit(Perpetual storage perpetual, Context memory context) internal {
        // update account
        perpetual.traderAccounts[context.taker] = context.takerAccount;
        perpetual.traderAccounts[context.maker] = context.makerAccount;
        // fee
    }

}