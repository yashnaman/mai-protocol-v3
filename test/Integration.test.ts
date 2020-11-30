const { ethers } = require("hardhat");
const { expect } = require("chai");
import { BigNumber as BN } from "ethers";
import {
    toWei,
    fromWei,
    createFactory,
    createContract,
    createPerpetualFactory
} from "../scripts/utils";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { PerpetualFactory } from "../typechain/PerpetualFactory"
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

    it("broker", async () => {
        var gs = new GasStat();
        const accounts = await ethers.getSigners();
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const vault = accounts[9];

        var broker = await createContract("contracts/broker/BrokerRelay.sol:BrokerRelay");
        const order = {
            trader: user1.address, // trader
            broker: broker.address, // broker
            relayer: user1.address, // relayer
            perpetual: "0x0000000000000000000000000000000000000000", // perpetual
            referrer: "0x0000000000000000000000000000000000000000", // referrer
            amount: 1000,
            priceLimit: 2000,
            data: ethers.utils.solidityPack(["uint64", "uint32", "uint8", "uint8", "uint64"], [1606217568, 1, 1, 1, 123456]).padEnd(66, "0"),
            chainID: 1,
        };

        const brokerUser1 = await BrokerRelayFactory.connect(broker.address, user1);
        await brokerUser1.deposit({ value: 10000 });
        console.log((await brokerUser1.balanceOf(user1.address)).toString());
        await gs.collect("batchTrade 1", broker.batchTrade([order], [100], ["0x"], [100]));

        gs.summary()
    });

    it("main", async () => {
        var gs = new GasStat();
        // users
        const accounts = await ethers.getSigners();
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const vault = accounts[9];
        const none = "0x0000000000000000000000000000000000000000";

        // create components
        var weth = await createContract("WETH9");
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var oracle = await createContract("OracleWrapper", [ctk.address]);
        var lpTokenTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var maker = await createContract(
            "PerpetualMaker",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                vault.address,
                toWei("0.001")
            ]
        );
        var perpTemplate = await (await createPerpetualFactory()).deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");
        await maker.createPerpetual(
            oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            998,
        );

        const n = await maker.totalPerpetualCount();
        const allPerpetuals = await maker.listPerpetuals(0, n.toString());
        const perpetualFactory = await createPerpetualFactory();
        const perp = await perpetualFactory.attach(allPerpetuals[allPerpetuals.length - 1]);

        // oracle
        var now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("500"), now);
        await oracle.setIndexPrice(toWei("500"), now);

        // overview
        print(await perp.callStatic.information());
        print(await perp.callStatic.state());

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
        await ctkUser1.approve(perp.address, toWei("100000"));
        const ctkUser2 = await CustomErc20Factory.connect(ctk.address, user2);
        await ctkUser2.approve(perp.address, toWei("100000"));

        // deposit
        const perpUser1 = await PerpetualFactory.connect(perp.address, user1);
        await gs.collect("deposit", perpUser1.deposit(user1.address, toWei("100")));
        console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
        print(await perpUser1.marginAccount(user1.address));

        // lp
        const perpUser2 = await PerpetualFactory.connect(perp.address, user2);
        await gs.collect("addLiquidatity", perpUser2.addLiquidatity(toWei("1000")));
        const shareUser2 = await CustomErc20Factory.connect(await perp.shareToken(), user2);
        console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        // trade 1
        await gs.collect("trade 1 - open", perpUser1.trade(user1.address, toWei("0.1"), toWei("506"), now + 999999, none));
        print(await perpUser1.marginAccount(user1.address));

        // trade 2
        await gs.collect("trade 2 - open", perpUser1.trade(user1.address, toWei("0.05"), toWei("550"), now + 999999, none));
        print(await perpUser1.marginAccount(user1.address));

        // trade 3
        await gs.collect("trade 3 - revert", perpUser1.trade(user1.address, toWei("-0.2"), toWei("400"), now + 999999, none));
        print(await perpUser1.marginAccount(user1.address));

        // trade 4
        await gs.collect("trade 4 - close all", perpUser1.trade(user1.address, toWei("0.05"), toWei("510"), now + 999999, none));
        print(await perpUser1.marginAccount(user1.address));

        // withdraw
        await gs.collect("withdraw", perpUser1.withdraw(user1.address, toWei("10")));
        console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
        print(await perpUser1.marginAccount(user1.address));

        // remove lp
        await gs.collect("removeLiquidatity", perpUser2.removeLiquidatity(await shareUser2.balanceOf(user2.address)));
        console.log("share:", fromWei(await shareUser2.balanceOf(user2.address)));
        console.log("ctk  :", fromWei(await ctkUser2.balanceOf(user2.address)));

        gs.summary();
    })
})
