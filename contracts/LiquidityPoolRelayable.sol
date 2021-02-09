// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "./LiquidityPool.sol";
import "./l2adapter/RelayRecipient.sol";

contract LiquidityPoolRelayable is LiquidityPool, RelayRecipient {
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, RelayRecipient)
        returns (address payable)
    {
        return RelayRecipient._msgSender();
    }

    bytes32[50] private __gap;
}
