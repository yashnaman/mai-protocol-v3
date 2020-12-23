import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    toWei,
    createContract,
    getAccounts,
} from "../scripts/utils";

getDescription("Order", () => {
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
            referrer: "0x0000000000000000000000000000000000000005", // referrer
            liquidityPool: "0x0000000000000000000000000000000000000004", // liquidityPool
            minTradeAmount: 1000,
            amount: 1000,
            limitPrice: 2000,
            triggerPrice: 5000,
            chainID: 31337,
            expiredAt: 1234567,
            perpetualIndex: 0,
            brokerFeeLimit: 88,
            flags: 0xf0000000,
            salt: 667,
        };
        // expect(await testOrder.orderHash(order)).to.equal("0x283d1c30f1c4730dbca34fa5786bbfc18f5905182e1ec7f0ea78eed047140e41");
        expect(await testOrder.isCloseOnly(order)).to.be.true;
        expect(await testOrder.isMarketOrder(order)).to.be.true;
        expect(await testOrder.isStopLossOrder(order)).to.be.true;
        expect(await testOrder.isTakeProfitOrder(order)).to.be.true;
    });

    it("validateOrder", async () => {
        var now = Math.floor(Date.now() / 1000);
        const order = {
            trader: accounts[0].address, // trader
            broker: accounts[0].address, // broker
            relayer: accounts[0].address, // relayer
            liquidityPool: testOrder.address, // liquidityPool
            referrer: "0x0000000000000000000000000000000000000005", // referrer
            minTradeAmount: toWei("0.1"),
            amount: toWei("1"),
            limitPrice: toWei("500"),
            triggerPrice: toWei("400"),
            chainID: 31337,
            expiredAt: now + 10000,
            perpetualIndex: 0,
            brokerFeeLimit: 20,  // 20 gwei
            flags: 0x00000000,
            salt: 123456,
        };

        await testOrder.validateOrder(order, toWei("0.1"));

        await expect(testOrder.validateOrder(order, toWei("0"))).to.be.revertedWith("invalid amount");

        await expect(testOrder.validateOrder(order, toWei("1.1"))).to.be.revertedWith("amount exceeds order amount");

        await expect(testOrder.validateOrder(order, toWei("-0.1"))).to.be.revertedWith("invalid amount");

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
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("liquidity pool mismatch");
        order.liquidityPool = testOrder.address;

        order.chainID = 1;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("chainid mismatch");
        order.chainID = 31337;

        order.expiredAt = now - 1;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("order is expired");
        order.expiredAt = now + 100000;

        order.flags = 0x80000000;
        await expect(testOrder.validateOrder(order, toWei("0.1"))).to.be.revertedWith("trader has no position to close");
        order.flags = 0;

        await expect(testOrder.validateOrder(order, toWei("0.01"))).to.be.revertedWith("amount is less than min trade amount");
    })
});