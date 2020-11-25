import { ethers } from "hardhat";
import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { Signer, utils, BigNumber as BN } from "ethers";
import {
    toWei,
    fromWei,
    createContract,
    createTestPerpetual,
    getLinkedPerpetualFactory,
    createPerpetualMaker
} from "./utils";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { PerpetualFactory } from "../typechain/PerpetualFactory"
import { Perpetual } from "../typechain/Perpetual";

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
        var props = []
        for (var n in obj) {

            props.push([n, toString(obj[n])]);
        }
        console.table(props)
    }

    it("broker", async () => {
        var broker = await createContract("contracts/broker/BrokerRelay.sol:BrokerRelay");

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

        await broker.batchTrade([order], [100], [""], [100]);
    });

    it("main", async () => {
        // users
        const accounts = await ethers.getSigners();
        const user1 = accounts[1];
        const user2 = accounts[2];
        const user3 = accounts[3];
        const vault = accounts[9];

        // create components
        var ctk = await createContract("contracts/test/CustomERC20.sol:CustomERC20", ["collateral", "CTK", 18]);
        var oracle = await createContract("contracts/oracle/mock/OracleWrapper.sol:OracleWrapper", [ctk.address]);
        var lpTokenTemplate = await createContract("contracts/governance/ShareToken.sol:ShareToken");
        var govTemplate = await createContract("contracts/governance/Governor.sol:Governor");
        var perpTemplate = await createTestPerpetual();
        var maker = await createPerpetualMaker(govTemplate, lpTokenTemplate, perpTemplate, vault, toWei("0.001"));
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
        const perpetualFactory = await getLinkedPerpetualFactory();
        const perp = await perpetualFactory.attach(allPerpetuals[allPerpetuals.length - 1]);

        // overview
        print(await perp.callStatic.information());
        print(await perp.callStatic.state());

        // oracle
        var now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("500"), now);
        await oracle.setIndexPrice(toWei("500"), now);

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
        await ctkUser1.approve(perp.address, toWei("100000"));
        const ctkUser2 = await CustomErc20Factory.connect(ctk.address, user2);
        await ctkUser2.approve(perp.address, toWei("100000"));

        // deposit
        const perpUser1 = await PerpetualFactory.connect(perp.address, user1);
        await perpUser1.deposit(user1.address, toWei("100"));
        console.log(fromWei(await ctkUser1.balanceOf(user1.address)));
        print(await perpUser1.marginAccount(user1.address));

        // lp
        const perpUser2 = await PerpetualFactory.connect(perp.address, user1);
        await perpUser2.addLiquidatity(toWei("1000"));

    })

})
