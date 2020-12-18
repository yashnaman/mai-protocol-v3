const { ethers } = require("hardhat");
const { expect } = require("chai");
import { BigNumber as BN } from "ethers";
import {
    toWei,
    fromWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { LiquidityPoolFactory } from "../typechain/LiquidityPoolFactory"
import { BrokerRelayFactory } from "../typechain/BrokerRelayFactory";

type Pair = Array<string>

class GasStat {
    collection: Array<Pair> = [];

    format(x) {
        return x.split('').reverse().map(function (a, i) { return a + ((i || 1) % 3 || a == '-' ? '' : ','); }).reverse().join('');
    }

    async collect(name, f) {
        const tx = await f;
        const receipt = await tx.wait();
        this.collection.push([name.padEnd(24), this.format(receipt.gasUsed.toString()).padStart(10)]);
    }

    summary() {
        console.table(this.collection)
    }
}

describe("integration", () => {

    function toString(n) {
        if (n instanceof BN) {
            return fromWei(n.toString());
        } else if (n instanceof Array) {
            return n.map(toString);
        }
        return n;
    }

    function print(obj) {
        return;
        var props = []
        for (var n in obj) {
            props.push([n, toString(obj[n])]);
        }
        console.table(props)
    }

    it("main", async () => {
        var gs = new GasStat();
        // users
        const accounts = await ethers.getSigners();
        const user0 = accounts[0];
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const vault = accounts[9];
        const none = "0x0000000000000000000000000000000000000000";

        // create components
        var weth = await createContract("WETH9");
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                vault.address,
                toWei("0.001")
            ]
        );
        var perpTemplate = await (await createLiquidityPoolFactory()).deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");
        await maker.createLiquidityPool(ctk.address, 998);

        const n = await maker.liquidityPoolCount();
        const allLiquidityPools = await maker.listLiquidityPools(0, n.toString());
        const perp = await LiquidityPoolFactory.connect(allLiquidityPools[allLiquidityPools.length - 1], user0);

        // oracle
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle4 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let updatePrice = async (price1, price2, price3, price4) => {
            let now = Math.floor(Date.now() / 1000);
            await oracle1.setMarkPrice(price1, now);
            await oracle1.setIndexPrice(price1, now);
            await oracle2.setMarkPrice(price2, now);
            await oracle2.setIndexPrice(price2, now);
            await oracle3.setMarkPrice(price3, now);
            await oracle3.setIndexPrice(price3, now);
            await oracle4.setMarkPrice(price4, now);
            await oracle4.setIndexPrice(price4, now);
        }
        await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))

        await perp.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.finalize();

        // overview
        const info = await perp.liquidityPoolInfo();

        print(info);
        print(await perp.callStatic.perpetualInfo(0));

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
        await ctkUser1.approve(perp.address, toWei("100000"));
        const ctkUser2 = await CustomErc20Factory.connect(ctk.address, user2);
        await ctkUser2.approve(perp.address, toWei("100000"));

        // deposit
        const perpUser1 = await LiquidityPoolFactory.connect(perp.address, user1);
        await gs.collect("deposit", perpUser1.deposit(0, user1.address, toWei("100")));
        print(await perpUser1.marginAccount(0, user1.address));

        // lp
        await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
        const perpUser2 = await LiquidityPoolFactory.connect(perp.address, user2);
        await gs.collect("addLiquidity", perpUser2.addLiquidity(toWei("1000")));
        const shareUser2 = await CustomErc20Factory.connect(info[0][5], user2);
        console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        print(await perp.callStatic.liquidityPoolInfo());

        let now = Math.floor(Date.now() / 1000);
        // trade 1
        await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
        await gs.collect("trade 1 - open", perpUser1.trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, false));
        print(await perpUser1.marginAccount(0, user1.address));

        // trade 2
        await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
        await gs.collect("trade 2 - open", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        print(await perpUser1.marginAccount(0, user1.address));

        // trade 3
        await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
        await gs.collect("trade 3 - revert", perpUser1.trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, false));
        print(await perpUser1.marginAccount(0, user1.address));

        // trade 4
        await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        await gs.collect("trade 4 - close all", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        print(await perpUser1.marginAccount(0, user1.address));

        // broker
        var broker = await createContract("BrokerRelay");
        const brokerUser1 = await BrokerRelayFactory.connect(broker.address, user1);
        await brokerUser1.deposit({ value: toWei("0.2") });
        console.log((await brokerUser1.balanceOf(user1.address)).toString());

        const order = {
            trader: user1.address, // trader
            broker: broker.address, // broker
            relayer: user1.address, // relayer
            liquidityPool: perpUser1.address, // liquidityPool
            minTradeAmount: 0,
            referrer: "0x0000000000000000000000000000000000000000", // referrer
            amount: toWei("0.1"),
            limitPrice: toWei("1000"),
            triggerPrice: 0,
            chainID: 31337,
            expiredAt: 2616217568,
            perpetualIndex: 0,
            brokerFeeLimit: 1000000000,
            flags: 0x00000000,
            salt: 667,
        };
        const OrderModule = await createContract("OrderModule");
        const testOrder = await createContract("TestOrder", [], { OrderModule });
        const orderHash = await testOrder.orderHash(order);
        const signature = await user1.signMessage(ethers.utils.arrayify(orderHash));
        await gs.collect("trade 5 - batchTrade", brokerUser1.batchTrade([order], [toWei("0.1")], [signature], [toWei("0.01")]));
        // await gs.collect("trade 5 - batchTrade", perpUser1.brokerTrade(order, toWei("0.1"), signature));
        print(await perpUser1.marginAccount(0, user1.address));

        // trade 4
        await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        await gs.collect("trade 6 - close all", perpUser1.trade(0, user1.address, toWei("-0.1"), toWei("0"), now + 999999, none, false));
        print(await perpUser1.marginAccount(0, user1.address));

        // withdraw
        await updatePrice(toWei("506"), toWei("607"), toWei("708"), toWei("809"))
        await gs.collect("withdraw", perpUser1.withdraw(0, user1.address, toWei("10")));
        console.log(fromWei(await ctkUser1.balanceOf(user1.address)));

        var { cashBalance, positionAmount } = await perpUser2.marginAccount(0, perpUser2.address);
        console.log(fromWei(cashBalance), fromWei(positionAmount));

        // remove lp
        await updatePrice(toWei("507"), toWei("608"), toWei("709"), toWei("800"))
        await gs.collect("removeLiquidity", perpUser2.removeLiquidity(await shareUser2.balanceOf(user2.address)));
        console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        gs.summary();
    })

    it("main - eth", async () => {
        var gs = new GasStat();
        // users
        const accounts = await ethers.getSigners();
        const user0 = accounts[0];
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const vault = accounts[9];
        const none = "0x0000000000000000000000000000000000000000";

        // create components
        var weth = await createContract("WETH9");
        var lpTokenTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                vault.address,
                toWei("0.001")
            ]
        );
        var perpTemplate = await (await createLiquidityPoolFactory()).deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");
        await maker.createLiquidityPool(weth.address, 998);

        const n = await maker.liquidityPoolCount();
        const allLiquidityPools = await maker.listLiquidityPools(0, n.toString());
        const perp = await LiquidityPoolFactory.connect(allLiquidityPools[allLiquidityPools.length - 1], user0);

        // oracle
        let oracle1 = await createContract("OracleWrapper", ["ETH", "USD"]);
        let oracle2 = await createContract("OracleWrapper", ["ETH", "USD"]);
        let oracle3 = await createContract("OracleWrapper", ["ETH", "USD"]);
        let oracle4 = await createContract("OracleWrapper", ["ETH", "USD"]);

        let updatePrice = async (price1, price2, price3, price4) => {
            let now = Math.floor(Date.now() / 1000);
            await oracle1.setMarkPrice(price1, now);
            await oracle1.setIndexPrice(price1, now);
            await oracle2.setMarkPrice(price2, now);
            await oracle2.setIndexPrice(price2, now);
            await oracle3.setMarkPrice(price3, now);
            await oracle3.setIndexPrice(price3, now);
            await oracle4.setMarkPrice(price4, now);
            await oracle4.setIndexPrice(price4, now);
        }
        await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))

        await perp.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await perp.finalize();

        // overview
        print(await perp.callStatic.liquidityPoolInfo());
        print(await perp.callStatic.perpetualInfo(0));

        // get initial coins
        // await ctk.mint(user1.address, toWei("10000"));
        // await ctk.mint(user2.address, toWei("10000"));
        // const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
        // await ctkUser1.approve(perp.address, toWei("100000"));
        // const ctkUser2 = await CustomErc20Factory.connect(ctk.address, user2);
        // await ctkUser2.approve(perp.address, toWei("100000"));

        const info = await perp.liquidityPoolInfo();

        // deposit
        const perpUser1 = await LiquidityPoolFactory.connect(perp.address, user1);
        await gs.collect("deposit", perpUser1.deposit(0, user1.address, toWei("0"), { value: toWei("10") }));
        print(await perpUser1.marginAccount(0, user1.address));

        // lp
        await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
        const perpUser2 = await LiquidityPoolFactory.connect(perp.address, user2);
        await gs.collect("addLiquidity", perpUser2.addLiquidity(toWei("0"), { value: toWei("10") }));
        const shareUser2 = await CustomErc20Factory.connect(info[0][5], user2);
        console.log("share: ", fromWei(await shareUser2.balanceOf(user2.address)));

        // print(await perp.callStatic.liquidityPoolInfo());

        let now = Math.floor(Date.now() / 1000);
        // // trade 1
        // await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
        // await gs.collect("trade 1 - open", perpUser1.trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.marginAccount(0, user1.address));

        // // trade 2
        // await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
        // await gs.collect("trade 2 - open", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.marginAccount(0, user1.address));

        // // trade 3
        // await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
        // await gs.collect("trade 3 - revert", perpUser1.trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, false));
        // print(await perpUser1.marginAccount(0, user1.address));

        // // trade 4
        // await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        // await gs.collect("trade 4 - close all", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.marginAccount(0, user1.address));

        // // withdraw
        // await updatePrice(toWei("506"), toWei("607"), toWei("708"), toWei("809"))
        // await gs.collect("withdraw", perpUser1.withdraw(0, user1.address, toWei("10")));
        // console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
        // print(await perpUser1.marginAccount(0, user1.address));

        // // remove lp
        // await updatePrice(toWei("507"), toWei("608"), toWei("709"), toWei("800"))
        // await gs.collect("removeLiquidity", perpUser2.removeLiquidity(await shareUser2.balanceOf(user2.address)));
        // console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        // console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        gs.summary();
    })
})
