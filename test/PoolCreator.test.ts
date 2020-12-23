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

import { LiquidityPoolFactory } from "../typechain/LiquidityPoolFactory"

getDescription("integration", () => {

    function toString(n) {
        if (n instanceof BN) {
            return fromWei(n.toString());
        } else if (n instanceof Array) {
            return n.map(toString);
        }
        return n;
    }

    it("main", async () => {
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
        var creator = await createContract(
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
        await creator.addVersion(perpTemplate.address, 0, "initial version");
        await creator.createLiquidityPool(ctk.address, 998);

        const n = await creator.getLiquidityPoolCount();
        const allLiquidityPools = await creator.listLiquidityPools(0, n.toString());
        const perp = await LiquidityPoolFactory.connect(allLiquidityPools[allLiquidityPools.length - 1], user0);
    })
})
