import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    createContract,
} from "./utils";

describe("Order", () => {
    describe("signature", async () => {
        var testOrder;

        before(async () => {
            testOrder = await createContract("contracts/test/TestOrder.sol:TestOrder");
        })

        it("orderhash", async () => {
            // deadline: 1606217568,
            // version: 1,
            // orderType: 1,
            // isCloseOnly: true,
            // salt: 123456,
            console.log(ethers.utils.solidityPack(["uint64", "uint32", "uint8", "uint8", "uint64"], [1606217568, 1, 1, 1, 123456]).padEnd(66, "0"));
            // 0x000000005fbcef600000000101010001e2400000000000000000000000000000
            const order = {
                trader: "0x0000000000000000000000000000000000000001", // trader
                broker: "0x0000000000000000000000000000000000000002", // broker
                relayer: "0x0000000000000000000000000000000000000003", // relayer
                perpetual: "0x0000000000000000000000000000000000000004", // perpetual
                referrer: "0x0000000000000000000000000000000000000005", // referrer
                amount: 1000,
                priceLimit: 2000,
                data: ethers.utils.solidityPack(["uint64", "uint32", "uint8", "uint8", "uint64"], [1606217568, 1, 1, 1, 123456]).padEnd(66, "0"),
                chainID: 1,
            };


            console.log(await testOrder.orderHashDebug(order));
            console.log((await testOrder.deadline(order)).toString());
            console.log((await testOrder.version(order)).toString());
            console.log(await testOrder.orderType(order));
            console.log(await testOrder.isCloseOnly(order));
            console.log((await testOrder.salt(order)).toString());
        });
    });
});