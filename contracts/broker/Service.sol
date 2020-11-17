// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./Type.sol";
import "./libraries/OrderExt.sol";

contract BrokerService {
    using OrderExt for Order;

    mapping(bytes32 => int256) internal _filled;
    mapping(bytes32 => int256) internal _canceled;

    function batchTrade(
        address perpetual,
        Order[] calldata orders,
        int256[] calldata amounts,
        ActionOnFailure actionOnFailure
    ) external {
        uint256 chainID = _chainID();
        uint256 currentTimestamp = block.timestamp;
        uint256 numOrders = orders.length;
        for (uint256 i = 0; i < numOrders; i++) {
            require(orders[i].broker == msg.sender, "");
            require(orders[i].perpetual == perpetual, "");
            require(orders[i].chainID == chainID, "");
            require(orders[i].deadline >= currentTimestamp, "");
            require(orders[i].amount > 0, "");

            bytes32 orderID = order.id();
            int256 toFillAmount = orders[i].amount.sub(_filled[orderID]);
            require(toFillAmount > 0, "");
            require(amounts[i] <= toFillAmount, "");

            (bool success, ) = perpetual.call(
                abi.encodeWithSignature(
                    "trade(address,int256,int256,uint256",
                    orders[i].trader,
                    amounts[i],
                    orders[i].priceLimit,
                    orders[i].deadline
                )
            );
            require(success || actionOnFailure == ActionOnFailure.IGNORE, "");
        }
    }

    function _chainID() public pure returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}
