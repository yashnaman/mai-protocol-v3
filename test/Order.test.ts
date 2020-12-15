import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    toWei,
    createContract,
    getAccounts,
} from "../scripts/utils";

describe("Order", () => {
    var testOrder;
    let accounts;

    before(async () => {
        accounts = await getAccounts();
        // const CollateralModule = await createContract("CollateralModule");
        // const AMMModule = await createContract("AMMModule", [], { CollateralModule });
        // const FundingModule = await createContract("FundingModule", [], { AMMModule });
        const OrderModule = await createContract("OrderModule");
        testOrder = await createContract("TestOrder", [], { OrderModule });
    })

    it("signature", async () => {
        // deadline: 1606217568,
        // version: 1,
        // orderType: 1,
        // isCloseOnly: true,
        // salt: 123456,
        // console.log(ethers.utils.solidityPack(["uint64", "uint32", "uint8", "uint8", "uint64"], [1606217568, 1, 1, 1, 123456]).padEnd(66, "0"));
        // 0x000000005fbcef600000000101010001e2400000000000000000000000000000
        const order = {
            trader: "0x0000000000000000000000000000000000000001", // trader
            broker: "0x0000000000000000000000000000000000000002", // broker
            relayer: "0x0000000000000000000000000000000000000003", // relayer
            liquidityPool: "0x0000000000000000000000000000000000000004", // liquidityPool
            marketIndex: 0,
            referrer: "0x0000000000000000000000000000000000000005", // referrer
            amount: 1000,
            priceLimit: 2000,
            data: ethers.utils.solidityPack(["uint64", "uint32", "uint8", "uint8", "uint64"], [1606217568, 1, 1, 1, 123456]).padEnd(66, "0"),
            chainID: 1,
        };
        expect(await testOrder.orderHash(order)).to.equal("0xfa80f29153ad5c4b4b1eb88f8bcbed96b4aea311d8ddf7307e54737dd2416ef4");
        expect(await testOrder.deadline(order)).to.equal(1606217568);
        expect(await testOrder.version(order)).to.equal(1);
        expect(await testOrder.orderType(order)).to.equal(1);
        expect(await testOrder.isCloseOnly(order)).to.be.true;
        expect(await testOrder.salt(order)).to.equal(123456);
    });

    it("validateOrder", async () => {
        var now = Math.floor(Date.now() / 1000);
        const order = {
            trader: accounts[0].address, // trader
            broker: accounts[0].address, // broker
            relayer: accounts[0].address, // relayer
            liquidityPool: testOrder.address, // liquidityPool
            marketIndex: 0,
            referrer: "0x0000000000000000000000000000000000000005", // referrer
            amount: toWei("1"),
            priceLimit: toWei("500"),
            data: ethers.utils.solidityPack(
                ["uint64", "uint32", "uint8", "uint8", "uint64"],
                [now + 10000, 3, 1, 0, 123456]
            ).padEnd(66, "0"),
            chainID: 31337,
        };
        await testOrder.validateOrder(order, toWei("0.1"));

        await expect(testOrder.validateOrder(order, toWei("0"))).to.be.revertedWith("amount is 0");

        await expect(testOrder.validateOrder(order, toWei("1.1"))).to.be.revertedWith("no enough amount to fill");

        await expect(testOrder.validateOrder(order, toWei("-0.1"))).to.be.revertedWith("side mismatch");

        order.amount = toWei("0");
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("order amount is 0");
        order.amount = toWei("1");

        order.broker = accounts[1].address;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("broker mismatch");
        order.broker = accounts[0].address;

        order.relayer = accounts[1].address;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("relayer mismatch");
        order.relayer = accounts[0].address;

        order.liquidityPool = accounts[1].address;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("liquidityPool mismatch");
        order.liquidityPool = testOrder.address;

        order.chainID = 1;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("chainid mismatch");
        order.chainID = 31337;

        let tmp = order.data;
        order.data = ethers.utils.solidityPack(
            ["uint64", "uint32", "uint8", "uint8", "uint64"],
            [now - 100, 3, 1, 0, 123456]
        ).padEnd(66, "0")
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("order is expired");

        order.data = tmp;
        order.data = ethers.utils.solidityPack(
            ["uint64", "uint32", "uint8", "uint8", "uint64"],
            [now + 10000, 1, 1, 0, 123456]
        ).padEnd(66, "0")
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("order version is not supported");


        // // order.data = tmp;
        // // order.data = ethers.utils.solidityPack(
        // //     ["uint64", "uint32", "uint8", "uint8", "uint64"],
        // //     [now + 10000, 3, 3, 0, 123456]
        // // ).padEnd(66, "0")
        // // await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("invalid opcode");

        // order.data = tmp;
        // order.data = ethers.utils.solidityPack(
        //     ["uint64", "uint32", "uint8", "uint8", "uint64"],
        //     [now + 10000, 3, 2, 0, 123456]
        // ).padEnd(66, "0")
        // await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("not closing order");

        // order.data = tmp;
        // order.data = ethers.utils.solidityPack(
        //     ["uint64", "uint32", "uint8", "uint8", "uint64"],
        //     [now + 10000, 3, 1, 1, 123456]
        // ).padEnd(66, "0")
        // await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("not closing order");

        // await testOrder.setPositionAmount(accounts[0].address, toWei("-0.05"));
        // await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("no enough amount to close");

        order.data = tmp;
        await testOrder.setPositionAmount(accounts[0].address, toWei("-0.05"));
        await testOrder.validateOrder(order, toWei("0.05"));

        await testOrder.fillOrder(order, toWei("0.9"));
        await expect(testOrder.validateOrder(order, toWei("0.11"))).to.be.revertedWith("no enough amount to fill");

        await expect(testOrder.fillOrder(order, toWei("0.11"))).to.be.revertedWith("no enough amount to fill");
        await testOrder.cancelOrder(order);
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("order is canceled");
        await expect(testOrder.cancelOrder(order)).to.be.revertedWith("order is canceled");
    })

    it("truncateAmount", async () => {
    })

    it("cancelOrder", async () => {
    })

    it("fillOrder", async () => {
    })
});