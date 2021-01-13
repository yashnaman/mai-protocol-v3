import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    toWei,
    createContract,
    getAccounts,
} from "../scripts/utils";
import { userInfo } from "os";

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

        await expect(testOrder.validateOrder(order, toWei("0.01"))).to.be.revertedWith("amount is less than min trade amount");
    })

    it("decompress", async () => {
        /**
        testOrder.trader = address(0x1111111111111111111111111111111111111111);
        testOrder.broker = address(0x2222222222222222222222222222222222222222);
        testOrder.relayer = address(0x3333333333333333333333333333333333333333);
        testOrder.referrer = address(0x4444444444444444444444444444444444444444);
        testOrder.liquidityPool = address(0x5555555555555555555555555555555555555555);

        testOrder.minTradeAmount = 7;
        testOrder.amount = 8;
        testOrder.limitPrice = 9;
        testOrder.triggerPrice = 10;
        testOrder.chainID = 15;

        testOrder.expiredAt = 11;
        testOrder.perpetualIndex = 6;
        testOrder.brokerFeeLimit = 12;
        testOrder.flags = 0xffffffff;
        testOrder.salt = 14;
        r = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        s = 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        v = 27
        signType = 1
         */
        const data = "0x11111111111111111111111111111111111111112222222222222222222222222222222222222222333333333333333333333333333333333333333344444444444444444444444444444444444444445555555555555555555555555555555555555555000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000f000000000000000b000000060000000cffffffff0000000e1b01aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
        var { order, signature } = await testOrder.decompress(data);
        expect(order.trader).to.equal("0x1111111111111111111111111111111111111111");
        expect(order.broker).to.equal("0x2222222222222222222222222222222222222222");
        expect(order.relayer).to.equal("0x3333333333333333333333333333333333333333");
        expect(order.referrer).to.equal("0x4444444444444444444444444444444444444444");
        expect(order.liquidityPool).to.equal("0x5555555555555555555555555555555555555555");

        expect(order.minTradeAmount).to.equal(7);
        expect(order.amount).to.equal(8);
        expect(order.limitPrice).to.equal(9);
        expect(order.triggerPrice).to.equal(10);
        expect(order.chainID).to.equal(15);

        expect(order.expiredAt).to.equal(11);
        expect(order.perpetualIndex).to.equal(6);
        expect(order.brokerFeeLimit).to.equal(12);
        expect(order.flags).to.equal(0xffffffff);
        expect(order.salt).to.equal(14);

        expect(signature.slice(2, 66)).to.equal("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"); // r
        expect(signature.slice(66, 130)).to.equal("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"); // s
        expect(signature.slice(130, 134)).to.equal("1b01"); // v

        // const data2 = "0x276eb779d7ca51a5f7fba02bf83d9739da11e3ba335780c0f1dc2537a3874176f7d7737b32c243b2d595f7c2c071d3fd8f5587931edf34e92f9ad39f301ec46606aa95da4b8b5b8c219044b797a21e050000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000056bc75e2d6310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000539000000005fff32cf000000000000000100000000000000011c001548ffc535b274758042147da29f1e87a6046df6c947bcfe9f74c9e2c9de61cb797306681418cd08da81cfaa4dda043449e98f34ab345fb6ac3f2a6d230ca9a9";
        // var { order, signature } = await testOrder.decompress(data2);
    })

    it("signer", async () => {
        const order = {
            trader: "0x1111111111111111111111111111111111111111",
            broker: "0x2222222222222222222222222222222222222222",
            relayer: "0x3333333333333333333333333333333333333333",
            referrer: "0x4444444444444444444444444444444444444444",
            liquidityPool: "0x5555555555555555555555555555555555555555",
            minTradeAmount: 7,
            amount: 8,
            limitPrice: 9,
            triggerPrice: 10,
            chainID: 15,
            expiredAt: 11,
            perpetualIndex: 6,
            brokerFeeLimit: 12,
            flags: 0xffffffff,
            salt: 14,
        }
        var orderHash = await testOrder.orderHash(order);
        const user0 = accounts[0];
        const sig = await user0.signMessage(ethers.utils.arrayify(orderHash));
        const addr = await testOrder.getSigner(order, sig);
        console.log("orderHash:", orderHash)
        console.log("signature:", sig)
        expect(user0.address).to.equal(addr);
    })
});