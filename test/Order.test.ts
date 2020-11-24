import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { Signer, utils } from "ethers";
import {
    toWei,
    fromWei,
    createContract,
} from "./utils";

describe("Order", () => {
    describe("signature", async () => {
        var testOrder;

        before(async () => {
            testOrder = await createContract("contracts/test/TestOrder.sol:TestOrder");
        })

        it("orderhash", async () => {
            const order = {
                trader: "0x0000000000000000000000000000000000000001", // trader
                broker: "0x0000000000000000000000000000000000000002", // broker
                relayer: "0x0000000000000000000000000000000000000003", // relayer
                perpetual: "0x0000000000000000000000000000000000000004", // perpetual
                referrer: "0x0000000000000000000000000000000000000005", // referrer
                amount: 1000,
                priceLimit: 2000,
                deadline: 1606217568,
                version: 1,
                orderType: 1,
                isCloseOnly: true,
                salt: 123456,
                chainID: 1,
            };
            console.log(await testOrder.orderHashDebug(order));
        });
    });
});