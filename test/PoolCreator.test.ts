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

describe("PoolCreator", () => {

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
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var creator = await createContract(
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
        var perpTemplate = await (await createLiquidityPoolFactory()).deploy();
        await creator.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await creator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);

        await creator.createLiquidityPool(ctk.address, 18, false, 998);
        const n = await creator.getLiquidityPoolCount();
        const allLiquidityPools = await creator.listLiquidityPools(0, n.toString());

        expect(allLiquidityPools[allLiquidityPools.length - 1]).to.equal(perpAddr);
    })


    it("implementations", async () => {
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
        var lpTokenTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var creator = await createContract(
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

        var perpTemplate1 = await (await createLiquidityPoolFactory()).deploy();
        var perpTemplate2 = await (await createLiquidityPoolFactory()).deploy();
        var perpTemplate3 = await (await createLiquidityPoolFactory()).deploy();

        await creator.addVersion(perpTemplate1.address, 0, "1st version");
        await expect(creator.addVersion(perpTemplate1.address, 0, "1st version")).to.be.revertedWith("implementation is already existed");
        expect(await creator.getLatestVersion()).to.equal(perpTemplate1.address);

        await creator.addVersion(perpTemplate2.address, 0, "2nd version");
        expect(await creator.getLatestVersion()).to.equal(perpTemplate2.address);

        await creator.addVersion(perpTemplate3.address, 1, "3rd version");
        expect(await creator.getLatestVersion()).to.equal(perpTemplate3.address);

        expect(await creator.isVersionValid(perpTemplate1.address)).to.be.true;
        expect(await creator.isVersionValid(creator.address)).to.be.false;

        expect(await creator.isVersionCompatibleWith(perpTemplate1.address, perpTemplate3.address)).to.be.true;
        expect(await creator.isVersionCompatibleWith(perpTemplate3.address, perpTemplate1.address)).to.be.false;

        const perpAddr1 = await creator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await creator.createLiquidityPool(ctk.address, 18, false, 998);
        const perpAddr2 = await creator.callStatic.createLiquidityPool(ctk.address, 18, false, 999);
        await creator.createLiquidityPool(ctk.address, 18, false, 999);

        const n = await creator.getLiquidityPoolCount();
        expect(n).to.equal(2);

        const allLiquidityPools = await creator.listLiquidityPools(0, n.toString());
        expect(allLiquidityPools[0]).to.equal(perpAddr1);
        expect(allLiquidityPools[1]).to.equal(perpAddr2);
    })



})
