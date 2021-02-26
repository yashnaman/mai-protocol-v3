import BigNumber from 'bignumber.js';
import { expect, use } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createLiquidityPoolFactory,
    createFactory,
} from '../scripts/utils';
const { ethers } = require("hardhat");

describe('LiquidityPool', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let vault;
    let ctk;
    let stk;
    let oracle;
    let poolCreator;
    let LiquidityPoolFactory;
    let liquidityPool;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        vault = accounts[9];
    })

    beforeEach(async () => {
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        poolCreator = await createContract(
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
        LiquidityPoolFactory = await createLiquidityPoolFactory();
        await symbol.addWhitelistedFactory(poolCreator.address);
    });

    it("versionControl", async () => {
        await expect(poolCreator.getLatestVersion()).to.be.revertedWith("no version")
        await expect(poolCreator.addVersion("0x0000000000000000000000000000000000000000", 0, "version0")).to.be.revertedWith("invalid implementation");

        var implVersion1 = await LiquidityPoolFactory.deploy();
        const tx1 = await poolCreator.addVersion(implVersion1.address, 1, "version1");
        expect(await poolCreator.getLatestVersion()).to.equal(implVersion1.address)
        await expect(poolCreator.addVersion(implVersion1.address, 0, "version0")).to.be.revertedWith("implementation is already existed");
        await expect(poolCreator.addVersion(user0.address, 0, "version0")).to.be.revertedWith("implementation must be contract");

        var implVersion2 = await LiquidityPoolFactory.deploy();
        const tx2 = await poolCreator.addVersion(implVersion2.address, 2, "version2");
        expect(await poolCreator.getLatestVersion()).to.equal(implVersion2.address)

        var implVersion3 = await LiquidityPoolFactory.deploy();
        const tx3 = await poolCreator.addVersion(implVersion3.address, 2, "version3");
        expect(await poolCreator.getLatestVersion()).to.equal(implVersion3.address)

        var block1 = await ethers.provider.getBlock(tx1.blockNumber)
        var result = await poolCreator.getDescription(implVersion1.address);
        expect(result.creator).to.equal(user0.address);
        expect(result.creationTime).to.equal(block1.timestamp);
        expect(result.compatibility).to.equal(1);
        expect(result.note).to.equal("version1");

        var block2 = await ethers.provider.getBlock(tx2.blockNumber)
        var result = await poolCreator.getDescription(implVersion2.address);
        expect(result.creator).to.equal(user0.address);
        expect(result.creationTime).to.equal(block2.timestamp);
        expect(result.compatibility).to.equal(2);
        expect(result.note).to.equal("version2");


        var block3 = await ethers.provider.getBlock(tx3.blockNumber)
        var result = await poolCreator.getDescription(implVersion3.address);
        expect(result.creator).to.equal(user0.address);
        expect(result.creationTime).to.equal(block3.timestamp);
        expect(result.compatibility).to.equal(2);
        expect(result.note).to.equal("version3");

        var result = await poolCreator.listAvailableVersions(0, 10);
        expect(result.length).to.equal(3);
        expect(result[0]).to.equal(implVersion1.address);
        expect(result[1]).to.equal(implVersion2.address);
        expect(result[2]).to.equal(implVersion3.address);

        expect(await poolCreator.isVersionCompatible(implVersion2.address, implVersion1.address)).to.be.true;
        expect(await poolCreator.isVersionCompatible(implVersion1.address, implVersion2.address)).to.be.false;
        expect(await poolCreator.isVersionCompatible(implVersion3.address, implVersion2.address)).to.be.true;
        expect(await poolCreator.isVersionCompatible(implVersion2.address, implVersion3.address)).to.be.true;
    })


    it("createLiquidityPoolWith", async () => {
        var implVersion1 = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(implVersion1.address, 1, "version1");
        var implVersion2 = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(implVersion2.address, 2, "version2");

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        const liquidityPoolAddr = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);

        const proxy1 = (await createContract("UpgradeableProxy", [liquidityPoolAddr, user0.address])).attach(liquidityPoolAddr);
        expect(await proxy1.implementation()).to.equal(implVersion2.address);

        const liquidityPoolAddr2 = await poolCreator.callStatic.createLiquidityPoolWith(implVersion1.address, ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPoolWith(implVersion1.address, ctk.address, 18, false, 998);

        const proxy2 = (await createContract("UpgradeableProxy", [liquidityPoolAddr, user0.address])).attach(liquidityPoolAddr2);
        expect(await proxy2.implementation()).to.equal(implVersion1.address);
    })

    it("tracer", async () => {
        var implVersion1 = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(implVersion1.address, 1, "version1");
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(0);

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        const liquidityPoolAddr1 = await poolCreator.connect(user1).callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.connect(user1).createLiquidityPool(ctk.address, 18, false, 998);
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(1);

        const liquidityPoolAddr2 = await poolCreator.connect(user2).callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.connect(user2).createLiquidityPool(ctk.address, 18, false, 998);
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(2);

        const liquidityPoolAddr3 = await poolCreator.connect(user2).callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.connect(user2).createLiquidityPool(ctk.address, 18, false, 998);
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(3);

        expect(await poolCreator.isLiquidityPool(liquidityPoolAddr1)).to.be.true;
        expect(await poolCreator.isLiquidityPool(liquidityPoolAddr2)).to.be.true;
        expect(await poolCreator.isLiquidityPool(liquidityPoolAddr3)).to.be.true;
        expect(await poolCreator.isLiquidityPool(user0.address)).to.be.false;

        var result = await poolCreator.listLiquidityPools(0, 100);
        expect(result[0]).to.equal(liquidityPoolAddr1)
        expect(result[1]).to.equal(liquidityPoolAddr2)
        expect(result[2]).to.equal(liquidityPoolAddr3)

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user0.address)).to.equal(0)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user0.address, 0, 100)
        expect(result.length).to.equal(0)

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user1.address)).to.equal(1)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user1.address, 0, 100)
        expect(result.length).to.equal(1)
        expect(result[0]).to.equal(liquidityPoolAddr1);

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user2.address)).to.equal(2)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user2.address, 0, 100)
        expect(result.length).to.equal(2)
        expect(result[0]).to.equal(liquidityPoolAddr2);
        expect(result[1]).to.equal(liquidityPoolAddr3);
    })


    it("tracer - 2", async () => {
        var implVersion1 = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(implVersion1.address, 1, "version1");

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        await oracle.setIndexPrice(toWei("1000"), 1000)
        await oracle.setMarkPrice(toWei("1000"), 1000)

        const liquidityPoolAddr1 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);

        const liquidityPool1 = await LiquidityPoolFactory.attach(liquidityPoolAddr1);
        await liquidityPool1.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool1.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool1.runLiquidityPool();

        const liquidityPoolAddr2 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);

        const liquidityPool2 = await LiquidityPoolFactory.attach(liquidityPoolAddr2);
        await liquidityPool2.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool2.runLiquidityPool();

        var users = [user1, user2, user3];

        for (let i = 0; i < users.length; i++) {
            await ctk.mint(users[i].address, toWei("100"))
            await ctk.connect(users[i]).approve(liquidityPoolAddr1, toWei("100"))
            await ctk.connect(users[i]).approve(liquidityPoolAddr2, toWei("100"))
        }

        await liquidityPool1.connect(user1).deposit(0, user1.address, toWei("1"))
        await liquidityPool2.connect(user1).deposit(0, user1.address, toWei("1"))

        await liquidityPool1.connect(user2).deposit(0, user2.address, toWei("1"))
        await liquidityPool1.connect(user2).deposit(1, user2.address, toWei("1"))

        await liquidityPool2.connect(user3).deposit(0, user3.address, toWei("1"))

        var result = await poolCreator.listActiveLiquidityPoolsOf(user1.address, 0, 100);
        expect(result.length).to.equal(2)
        expect(result[0].liquidityPool).to.equal(liquidityPoolAddr1);
        expect(result[0].perpetualIndex).to.equal(0);
        expect(result[1].liquidityPool).to.equal(liquidityPoolAddr2);
        expect(result[1].perpetualIndex).to.equal(0);

        var result = await poolCreator.listActiveLiquidityPoolsOf(user2.address, 0, 100);
        expect(result.length).to.equal(2)
        expect(result[0].liquidityPool).to.equal(liquidityPoolAddr1);
        expect(result[0].perpetualIndex).to.equal(0);
        expect(result[1].liquidityPool).to.equal(liquidityPoolAddr1);
        expect(result[1].perpetualIndex).to.equal(1);

        var result = await poolCreator.listActiveLiquidityPoolsOf(user3.address, 0, 100);
        expect(result.length).to.equal(1)
        expect(result[0].liquidityPool).to.equal(liquidityPoolAddr2);
        expect(result[0].perpetualIndex).to.equal(0);

    })
})
