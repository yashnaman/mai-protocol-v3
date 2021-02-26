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
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );

        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);

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
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )

        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        print(info);
        print(await perp.callStatic.getPerpetualInfo(0));


        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));

        await perp.forceToSyncState();

        // deposit
        await gs.collect("deposit", perp.connect(user1).deposit(0, user1.address, toWei("100")));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // lp
        await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
        await gs.collect("addLiquidity", perp.connect(user2).addLiquidity(toWei("1000")));
        // console.log("share:", fromWei(await stk.balanceOf(user2.address)));
        // console.log("ctk  :", fromWei(await ctk.balanceOf(user2.address)));

        print(await perp.callStatic.getLiquidityPoolInfo());


        let now = Math.floor(Date.now() / 1000);
        // trade 1
        await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
        await gs.collect("trade 1 - open", perp.connect(user1).trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 2
        await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
        await gs.collect("trade 2 - open", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 3
        await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
        await gs.collect("trade 3 - revert", perp.connect(user1).trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 4
        await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        await gs.collect("trade 4 - close all", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // broker
        var broker = await createContract("Broker");
        await broker.connect(user1).deposit({ value: toWei("0.2") });
        console.log((await broker.balanceOf(user1.address)).toString());

        // const order = {
        //     trader: user1.address, // trader
        //     broker: broker.address, // broker
        //     relayer: user1.address, // relayer
        //     liquidityPool: perpUser1.address, // liquidityPool
        //     minTradeAmount: 0,
        //     referrer: "0x0000000000000000000000000000000000000000", // referrer
        //     amount: toWei("0.1"),
        //     limitPrice: toWei("1000"),
        //     triggerPrice: 0,
        //     chainID: 31337,
        //     expiredAt: 2616217568,
        //     perpetualIndex: 0,
        //     brokerFeeLimit: 1000000000,
        //     flags: 0x00000000,
        //     salt: 667,
        // };
        // const OrderModule = await createContract("OrderModule");
        // const testOrder = await createContract("TestOrder", [], { OrderModule });
        // const orderHash = await testOrder.orderHash(order);
        // const signature = await user1.signMessage(ethers.utils.arrayify(orderHash));
        // await gs.collect("trade 5 - batchTrade", brokerUser1.batchTrade([order], [toWei("0.1")], [signature], [toWei("0.01")]));
        // await gs.collect("trade 5 - batchTrade", perpUser1.brokerTrade(order, toWei("0.1"), signature));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // // trade 4
        // await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        // await gs.collect("trade 6 - close all", perpUser1.trade(0, user1.address, toWei("-0.1"), toWei("0"), now + 999999, none, false));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // withdraw
        await updatePrice(toWei("506"), toWei("607"), toWei("708"), toWei("809"))
        await gs.collect("withdraw", perp.connect(user1).withdraw(0, user1.address, toWei("10")));
        // console.log(fromWei(await ctk.connect(user1).balanceOf(user1.address)));

        var { cash, position } = await perp.connect(user2).callStatic.getMarginAccount(0, perp.address);
        // console.log(fromWei(cash), fromWei(position));

        // remove lp
        await updatePrice(toWei("507"), toWei("608"), toWei("709"), toWei("800"))
        await gs.collect("removeLiquidity", perp.connect(user2).removeLiquidity(await stk.balanceOf(user2.address)));
        console.log("share:", fromWei(await stk.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctk.connect(user2).balanceOf(user2.address)));

        gs.summary();
    })

<<<<<<< HEAD
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
        var symbol = await createContract("SymbolService", [10000]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );
        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(weth.address, 18, false, 998);
        await maker.createLiquidityPool(weth.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);

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
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.runLiquidityPool();

        // overview
        print(await perp.callStatic.getLiquidityPoolInfo());
        print(await perp.callStatic.getPerpetualInfo(0));

        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        // deposit
        await gs.collect("deposit", perp.connect(user1).deposit(0, user1.address, toWei("0"), { value: toWei("10") }));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // lp
        await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
        await gs.collect("addLiquidity", perp.connect(user2).addLiquidity(toWei("0"), { value: toWei("10") }));
        console.log("share: ", fromWei(await stk.balanceOf(user2.address)));

        // print(await perp.callStatic.getLiquidityPoolInfo());

        let now = Math.floor(Date.now() / 1000);
        // // trade 1
        // await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
        // await gs.collect("trade 1 - open", perpUser1.trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // // trade 2
        // await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
        // await gs.collect("trade 2 - open", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // // trade 3
        // await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
        // await gs.collect("trade 3 - revert", perpUser1.trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, false));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // // trade 4
        // await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        // await gs.collect("trade 4 - close all", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
        // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

        // withdraw
        await updatePrice(toWei("506"), toWei("607"), toWei("708"), toWei("809"))
        await gs.collect("withdraw", perp.connect(user1).withdraw(0, user1.address, toWei("10")));
        // console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // // remove lp
        // await updatePrice(toWei("507"), toWei("608"), toWei("709"), toWei("800"))
        // await gs.collect("removeLiquidity", perpUser2.removeLiquidity(await shareUser2.balanceOf(user2.address)));
        // console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        // console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        gs.summary();
    })

    it("main - 6 decimals", async () => {
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
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 6]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );

        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 6, false, 998);
        await maker.createLiquidityPool(ctk.address, 6, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);


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
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        print(info);
        print(await perp.callStatic.getPerpetualInfo(0));


        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));

        // deposit
        await gs.collect("deposit", perp.connect(user1).deposit(0, user1.address, toWei("100")));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // lp
        await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
        await gs.collect("addLiquidity", perp.connect(user2).addLiquidity(toWei("1000")));
        console.log("share:", fromWei(await stk.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctk.balanceOf(user2.address)));

        print(await perp.callStatic.getLiquidityPoolInfo());

        let now = Math.floor(Date.now() / 1000);
        // trade 1
        await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
        await gs.collect("trade 1 - open", perp.connect(user1).trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 2
        await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
        await gs.collect("trade 2 - open", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 3
        await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
        await gs.collect("trade 3 - revert", perp.connect(user1).trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

        // trade 4
        await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
        await gs.collect("trade 4 - close all", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
        print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    });

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
        const vaultFeeRate = toWei("0.001");

        // create components
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                vaultFeeRate,
            ]
        );
        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);

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
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        print(info);
        print(await perp.callStatic.getPerpetualInfo(0));

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.mint(user3.address, toWei("100"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));
        await ctk.connect(user3).approve(perp.address, toWei("100000"));
        await ctk.mint(user3.address, toWei("100"));

        // lp - user2
        await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))
        await perp.connect(user2).addLiquidity(toWei("1000"));

        // deposit - user1 user3
        await perp.connect(user1).deposit(0, user1.address, toWei("100"));
        await perp.connect(user3).deposit(0, user3.address, toWei("100"));

        let now = Math.floor(Date.now() / 1000);
        // trade 1
        await perp.connect(user1).trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0)
        // trade 4
        await perp.connect(user1).trade(0, user1.address, toWei("-0.1"), toWei("0"), now + 999999, none, 0);

        // withdraw
        var { cash } = await perp.getMarginAccount(0, user1.address);
        await perp.connect(user1).withdraw(0, user1.address, cash);
        await perp.connect(user3).withdraw(0, user3.address, toWei("100"));
        await perp.connect(user2).removeLiquidity(toWei("1000"));

        console.log(fromWei(await ctk.balanceOf(perp.address)));
    })

    it("liquidate", async () => {
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
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );

        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);

        // oracle
        let oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        let updatePrice = async (price) => {
            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(price, now);
            await oracle.setIndexPrice(price, now);
        }
        await updatePrice(toWei("500"))

        await perp.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("10")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));

        // deposit
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));

        // lp
        await perp.connect(user2).addLiquidity(toWei("1000"));
        // console.log("share:", fromWei(await stk.balanceOf(user2.address)));
        // console.log("ctk  :", fromWei(await ctk.balanceOf(user2.address)));

        // trade
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1000"), now + 999999, none, 0);

        // var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
        await updatePrice(toWei("100"))
        await perp.connect(user1).forceToSyncState();

        // var { availableCash, position, margin, isMaintenanceMarginSafe, _ } = await perp.getMarginAccount(0, user1.address);
        // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
        // var { deltaCash } = await perp.queryTradeWithAMM(0, toWei("0").sub(position))
        // console.log(deltaCash.add(margin))

        await perp.connect(user2).donateInsuranceFund(0, toWei("1000"))

        await perp.connect(user3).liquidateByAMM(0, user1.address);
        var { availableCash, position, margin, isMaintenanceMarginSafe, _ } = await perp.getMarginAccount(0, user1.address);
        expect(availableCash).to.equal(0);
        expect(position).to.equal(0);
        console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
    })


    it("accesscontrol", async () => {
        // users
        const accounts = await ethers.getSigners();
        const user0 = accounts[0];
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const user4 = accounts[4];
        const vault = accounts[9];
        const none = "0x0000000000000000000000000000000000000000";

        // create components
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        var maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );

        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);

        // oracle
        let oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        let updatePrice = async (price) => {
            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(price, now);
            await oracle.setIndexPrice(price, now);
        }
        await updatePrice(toWei("500"))

        await perp.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("10")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();
        const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));

        await maker.connect(user1).grantPrivilege(user4.address, 0x7); // deposit withdraw

        // deposit
        await perp.connect(user4).deposit(0, user1.address, toWei("500"));
        var u1Account = await perp.getMarginAccount(0, user1.address);
        expect(u1Account.cash).to.equal(toWei("500"))
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9500"))

        var u4Account = await perp.getMarginAccount(0, user4.address);
        expect(u4Account.cash).to.equal(toWei("0"))
        expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0"))

        // lp
        await perp.connect(user2).addLiquidity(toWei("1000"));

        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user4).trade(0, user1.address, toWei("3"), toWei("1000"), now + 999999, none, 0);

        await perp.connect(user4).withdraw(0, user1.address, toWei("100"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9600"))
        expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0"))

        var u4Account = await perp.getMarginAccount(0, user4.address);
        expect(u4Account.cash).to.equal(toWei("0"))
        expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0"))
    })
=======
    // it("main - eth", async () => {
    //     var gs = new GasStat();
    //     // users
    //     const accounts = await ethers.getSigners();
    //     const user0 = accounts[0];
    //     const user1 = accounts[1];
    //     const user2 = accounts[2];
    //     const user3 = accounts[3];
    //     const vault = accounts[9];
    //     const none = "0x0000000000000000000000000000000000000000";

    //     // create components
    //     var weth = await createContract("WETH9");
    //     var symbol = await createContract("SymbolService", [10000]);
    //     var lpTokenTemplate = await createContract("LpGovernor");
    //     var govTemplate = await createContract("TestGovernor");
    //     var maker = await createContract(
    //         "PoolCreator",
    //         [
    //             govTemplate.address,
    //             lpTokenTemplate.address,
    //             weth.address,
    //             symbol.address,
    //             vault.address,
    //             toWei("0.001")
    //         ]
    //     );
    //     const LiquidityPoolFactory = await createLiquidityPoolFactory();

    //     await symbol.addWhitelistedFactory(maker.address);
    //     var perpTemplate = await LiquidityPoolFactory.deploy();
    //     await maker.addVersion(perpTemplate.address, 0, "initial version");

    //     const perpAddr = await maker.callStatic.createLiquidityPool(weth.address, 18, false, 998);
    //     await maker.createLiquidityPool(weth.address, 18, false, 998);

    //     const perp = await LiquidityPoolFactory.attach(perpAddr);

    //     // oracle
    //     let oracle1 = await createContract("OracleWrapper", ["ETH", "USD"]);
    //     let oracle2 = await createContract("OracleWrapper", ["ETH", "USD"]);
    //     let oracle3 = await createContract("OracleWrapper", ["ETH", "USD"]);
    //     let oracle4 = await createContract("OracleWrapper", ["ETH", "USD"]);

    //     let updatePrice = async (price1, price2, price3, price4) => {
    //         let now = Math.floor(Date.now() / 1000);
    //         await oracle1.setMarkPrice(price1, now);
    //         await oracle1.setIndexPrice(price1, now);
    //         await oracle2.setMarkPrice(price2, now);
    //         await oracle2.setIndexPrice(price2, now);
    //         await oracle3.setMarkPrice(price3, now);
    //         await oracle3.setIndexPrice(price3, now);
    //         await oracle4.setMarkPrice(price4, now);
    //         await oracle4.setIndexPrice(price4, now);
    //     }
    //     await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))

    //     await perp.createPerpetual(oracle1.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle2.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle3.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle4.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.runLiquidityPool();

    //     // overview
    //     print(await perp.callStatic.getLiquidityPoolInfo());
    //     print(await perp.callStatic.getPerpetualInfo(0));

    //     const info = await perp.getLiquidityPoolInfo();
    //     const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

    //     // deposit
    //     await gs.collect("deposit", perp.connect(user1).deposit(0, user1.address, toWei("0"), { value: toWei("10") }));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // lp
    //     await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
    //     await gs.collect("addLiquidity", perp.connect(user2).addLiquidity(toWei("0"), { value: toWei("10") }));
    //     console.log("share: ", fromWei(await stk.balanceOf(user2.address)));

    //     // print(await perp.callStatic.getLiquidityPoolInfo());

    //     let now = Math.floor(Date.now() / 1000);
    //     // // trade 1
    //     // await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
    //     // await gs.collect("trade 1 - open", perpUser1.trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, false));
    //     // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

    //     // // trade 2
    //     // await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
    //     // await gs.collect("trade 2 - open", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
    //     // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

    //     // // trade 3
    //     // await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
    //     // await gs.collect("trade 3 - revert", perpUser1.trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, false));
    //     // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

    //     // // trade 4
    //     // await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
    //     // await gs.collect("trade 4 - close all", perpUser1.trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, false));
    //     // print(await perpUser1.callStatic.getMarginAccount(0, user1.address));

    //     // withdraw
    //     await updatePrice(toWei("506"), toWei("607"), toWei("708"), toWei("809"))
    //     await gs.collect("withdraw", perp.connect(user1).withdraw(0, user1.address, toWei("10")));
    //     // console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // // remove lp
    //     // await updatePrice(toWei("507"), toWei("608"), toWei("709"), toWei("800"))
    //     // await gs.collect("removeLiquidity", perpUser2.removeLiquidity(await shareUser2.balanceOf(user2.address)));
    //     // console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
    //     // console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

    //     gs.summary();
    // })

    // it("main - 6 decimals", async () => {
    //     var gs = new GasStat();
    //     // users
    //     const accounts = await ethers.getSigners();
    //     const user0 = accounts[0];
    //     const user1 = accounts[1];
    //     const user2 = accounts[2];
    //     const user3 = accounts[3];
    //     const vault = accounts[9];
    //     const none = "0x0000000000000000000000000000000000000000";

    //     // create components
    //     var weth = await createContract("WETH9");
    //     var symbol = await createContract("SymbolService", [10000]);
    //     var ctk = await createContract("CustomERC20", ["collateral", "CTK", 6]);
    //     var lpTokenTemplate = await createContract("LpGovernor");
    //     var govTemplate = await createContract("TestGovernor");
    //     var maker = await createContract(
    //         "PoolCreator",
    //         [
    //             govTemplate.address,
    //             lpTokenTemplate.address,
    //             weth.address,
    //             symbol.address,
    //             vault.address,
    //             toWei("0.001")
    //         ]
    //     );

    //     const LiquidityPoolFactory = await createLiquidityPoolFactory();

    //     await symbol.addWhitelistedFactory(maker.address);
    //     var perpTemplate = await LiquidityPoolFactory.deploy();
    //     await maker.addVersion(perpTemplate.address, 0, "initial version");

    //     const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 6, false, 998);
    //     await maker.createLiquidityPool(ctk.address, 6, false, 998);

    //     const perp = await LiquidityPoolFactory.attach(perpAddr);


    //     // oracle
    //     let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle4 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let updatePrice = async (price1, price2, price3, price4) => {
    //         let now = Math.floor(Date.now() / 1000);
    //         await oracle1.setMarkPrice(price1, now);
    //         await oracle1.setIndexPrice(price1, now);
    //         await oracle2.setMarkPrice(price2, now);
    //         await oracle2.setIndexPrice(price2, now);
    //         await oracle3.setMarkPrice(price3, now);
    //         await oracle3.setIndexPrice(price3, now);
    //         await oracle4.setMarkPrice(price4, now);
    //         await oracle4.setIndexPrice(price4, now);
    //     }
    //     await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))


    //     await perp.createPerpetual(oracle1.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )

    //     await perp.createPerpetual(oracle2.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle3.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle4.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )

    //     await perp.runLiquidityPool();

    //     // overview
    //     const info = await perp.getLiquidityPoolInfo();
    //     const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

    //     print(info);
    //     print(await perp.callStatic.getPerpetualInfo(0));


    //     // get initial coins
    //     await ctk.mint(user1.address, toWei("10000"));
    //     await ctk.mint(user2.address, toWei("10000"));
    //     await ctk.connect(user1).approve(perp.address, toWei("100000"));
    //     await ctk.connect(user2).approve(perp.address, toWei("100000"));

    //     // deposit
    //     await gs.collect("deposit", perp.connect(user1).deposit(0, user1.address, toWei("100")));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // lp
    //     await updatePrice(toWei("501"), toWei("601"), toWei("701"), toWei("801"))
    //     await gs.collect("addLiquidity", perp.connect(user2).addLiquidity(toWei("1000")));
    //     console.log("share:", fromWei(await stk.balanceOf(user2.address)));
    //     console.log("ctk  :", fromWei(await ctk.balanceOf(user2.address)));

    //     print(await perp.callStatic.getLiquidityPoolInfo());

    //     let now = Math.floor(Date.now() / 1000);
    //     // trade 1
    //     await updatePrice(toWei("502"), toWei("603"), toWei("704"), toWei("805"))
    //     await gs.collect("trade 1 - open", perp.connect(user1).trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // trade 2
    //     await updatePrice(toWei("503"), toWei("604"), toWei("705"), toWei("806"))
    //     await gs.collect("trade 2 - open", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // trade 3
    //     await updatePrice(toWei("504"), toWei("605"), toWei("706"), toWei("807"))
    //     await gs.collect("trade 3 - revert", perp.connect(user1).trade(0, user1.address, toWei("-0.2"), toWei("0"), now + 999999, none, 0));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    //     // trade 4
    //     await updatePrice(toWei("505"), toWei("606"), toWei("707"), toWei("808"))
    //     await gs.collect("trade 4 - close all", perp.connect(user1).trade(0, user1.address, toWei("0.05"), toWei("1000"), now + 999999, none, 0));
    //     print(await perp.connect(user1).callStatic.getMarginAccount(0, user1.address));

    // });

    // it("main", async () => {
    //     var gs = new GasStat();
    //     // users
    //     const accounts = await ethers.getSigners();
    //     const user0 = accounts[0];
    //     const user1 = accounts[1];
    //     const user2 = accounts[2];
    //     const user3 = accounts[3];
    //     const vault = accounts[9];
    //     const none = "0x0000000000000000000000000000000000000000";
    //     const vaultFeeRate = toWei("0.001");

    //     // create components
    //     var weth = await createContract("WETH9");
    //     var symbol = await createContract("SymbolService", [10000]);
    //     var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
    //     var lpTokenTemplate = await createContract("LpGovernor");
    //     var govTemplate = await createContract("TestGovernor");
    //     var maker = await createContract(
    //         "PoolCreator",
    //         [
    //             govTemplate.address,
    //             lpTokenTemplate.address,
    //             weth.address,
    //             symbol.address,
    //             vault.address,
    //             vaultFeeRate,
    //         ]
    //     );
    //     const LiquidityPoolFactory = await createLiquidityPoolFactory();

    //     await symbol.addWhitelistedFactory(maker.address);
    //     var perpTemplate = await LiquidityPoolFactory.deploy();
    //     await maker.addVersion(perpTemplate.address, 0, "initial version");

    //     const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
    //     await maker.createLiquidityPool(ctk.address, 18, false, 998);

    //     const perp = await LiquidityPoolFactory.attach(perpAddr);

    //     // oracle
    //     let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let oracle4 = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let updatePrice = async (price1, price2, price3, price4) => {
    //         let now = Math.floor(Date.now() / 1000);
    //         await oracle1.setMarkPrice(price1, now);
    //         await oracle1.setIndexPrice(price1, now);
    //         await oracle2.setMarkPrice(price2, now);
    //         await oracle2.setIndexPrice(price2, now);
    //         await oracle3.setMarkPrice(price3, now);
    //         await oracle3.setIndexPrice(price3, now);
    //         await oracle4.setMarkPrice(price4, now);
    //         await oracle4.setIndexPrice(price4, now);
    //     }
    //     await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))

    //     await perp.createPerpetual(oracle1.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )

    //     await perp.createPerpetual(oracle2.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle3.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )
    //     await perp.createPerpetual(oracle4.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )

    //     await perp.runLiquidityPool();

    //     // overview
    //     const info = await perp.getLiquidityPoolInfo();
    //     const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

    //     print(info);
    //     print(await perp.callStatic.getPerpetualInfo(0));

    //     // get initial coins
    //     await ctk.mint(user1.address, toWei("10000"));
    //     await ctk.mint(user2.address, toWei("10000"));
    //     await ctk.mint(user3.address, toWei("100"));
    //     await ctk.connect(user1).approve(perp.address, toWei("100000"));
    //     await ctk.connect(user2).approve(perp.address, toWei("100000"));
    //     await ctk.connect(user3).approve(perp.address, toWei("100000"));
    //     await ctk.mint(user3.address, toWei("100"));

    //     // lp - user2
    //     await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))
    //     await perp.connect(user2).addLiquidity(toWei("1000"));

    //     // deposit - user1 user3
    //     await perp.connect(user1).deposit(0, user1.address, toWei("100"));
    //     await perp.connect(user3).deposit(0, user3.address, toWei("100"));

    //     let now = Math.floor(Date.now() / 1000);
    //     // trade 1
    //     await perp.connect(user1).trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0)
    //     // trade 4
    //     await perp.connect(user1).trade(0, user1.address, toWei("-0.1"), toWei("0"), now + 999999, none, 0);

    //     // withdraw
    //     var { cash } = await perp.getMarginAccount(0, user1.address);
    //     await perp.connect(user1).withdraw(0, user1.address, cash);
    //     await perp.connect(user3).withdraw(0, user3.address, toWei("100"));
    //     await perp.connect(user2).removeLiquidity(toWei("1000"));

    //     console.log(fromWei(await ctk.balanceOf(perp.address)));
    // })

    // it("liquidate", async () => {
    //     // users
    //     const accounts = await ethers.getSigners();
    //     const user0 = accounts[0];
    //     const user1 = accounts[1];
    //     const user2 = accounts[2];
    //     const user3 = accounts[3];
    //     const vault = accounts[9];
    //     const none = "0x0000000000000000000000000000000000000000";

    //     // create components
    //     var weth = await createContract("WETH9");
    //     var symbol = await createContract("SymbolService", [10000]);
    //     var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
    //     var lpTokenTemplate = await createContract("LpGovernor");
    //     var govTemplate = await createContract("TestGovernor");
    //     var maker = await createContract(
    //         "PoolCreator",
    //         [
    //             govTemplate.address,
    //             lpTokenTemplate.address,
    //             weth.address,
    //             symbol.address,
    //             vault.address,
    //             toWei("0.001")
    //         ]
    //     );

    //     const LiquidityPoolFactory = await createLiquidityPoolFactory();

    //     await symbol.addWhitelistedFactory(maker.address);
    //     var perpTemplate = await LiquidityPoolFactory.deploy();
    //     await maker.addVersion(perpTemplate.address, 0, "initial version");

    //     const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
    //     await maker.createLiquidityPool(ctk.address, 18, false, 998);

    //     const perp = await LiquidityPoolFactory.attach(perpAddr);

    //     // oracle
    //     let oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
    //     let updatePrice = async (price) => {
    //         let now = Math.floor(Date.now() / 1000);
    //         await oracle.setMarkPrice(price, now);
    //         await oracle.setIndexPrice(price, now);
    //     }
    //     await updatePrice(toWei("500"))

    //     await perp.createPerpetual(oracle.address,
    //         [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
    //         [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01")],
    //         [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //         [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
    //     )

    //     await perp.runLiquidityPool();

    //     // overview
    //     const info = await perp.getLiquidityPoolInfo();
    //     const stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

    //     // get initial coins
    //     await ctk.mint(user1.address, toWei("10000"));
    //     await ctk.mint(user2.address, toWei("10000"));
    //     await ctk.connect(user1).approve(perp.address, toWei("100000"));
    //     await ctk.connect(user2).approve(perp.address, toWei("100000"));

    //     // deposit
    //     await perp.connect(user1).deposit(0, user1.address, toWei("500"));

    //     // lp
    //     await perp.connect(user2).addLiquidity(toWei("1000"));
    //     // console.log("share:", fromWei(await stk.balanceOf(user2.address)));
    //     // console.log("ctk  :", fromWei(await ctk.balanceOf(user2.address)));

    //     // trade
    //     let now = Math.floor(Date.now() / 1000);
    //     await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1000"), now + 999999, none, 0);

    //     // var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
    //     // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
    //     await updatePrice(toWei("100"))
    //     await perp.connect(user1).forceToSyncState();

    //     // var { availableCash, position, margin, isMaintenanceMarginSafe, _ } = await perp.getMarginAccount(0, user1.address);
    //     // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
    //     // var { deltaCash } = await perp.queryTradeWithAMM(0, toWei("0").sub(position))
    //     // console.log(deltaCash.add(margin))

    //     await perp.connect(user2).donateInsuranceFund(0, toWei("1000"))

    //     await perp.connect(user3).liquidateByAMM(0, user1.address);
    //     var { availableCash, position, margin, isMaintenanceMarginSafe, _ } = await perp.getMarginAccount(0, user1.address);
    //     expect(availableCash).to.equal(0);
    //     expect(position).to.equal(0);
    //     console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);

    // })
>>>>>>> fix test
})
