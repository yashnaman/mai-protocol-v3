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

describe('Creator', () => {
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

    const versionKey = (lp, gov) => {
        return ethers.utils.solidityKeccak256(["address", "address"], [lp, gov]);
    }

    beforeEach(async () => {
        LiquidityPoolFactory = await createLiquidityPoolFactory();

        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        var govTemplate = await createContract("TestLpGovernor");
        poolCreator = await createContract("PoolCreator");
        await poolCreator.initialize(
            symbol.address,
            vault.address,
            toWei("0.001"),
        )
        await symbol.addWhitelistedFactory(poolCreator.address);
        // await poolCreator.addVersion(perpTemplate.address, govTemplate.address, 0, "initial version");
    });

    it("versionControl", async () => {
        await expect(poolCreator.getLatestVersion()).to.be.revertedWith("no version")
        await expect(poolCreator.addVersion(
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            0,
            "version0")
        ).to.be.revertedWith("implementation must be contract");

        var lpVersion1 = await LiquidityPoolFactory.deploy();
        var govVersion1 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion1.address,
            govVersion1.address,
            1,
            "version1"
        );
        const key1 = versionKey(lpVersion1.address, govVersion1.address);
        expect(await poolCreator.getLatestVersion()).to.equal(key1);

        await expect(poolCreator.addVersion(
            lpVersion1.address,
            govVersion1.address,
            0,
            "version1"
        )).to.be.revertedWith("implementation is already existed");
        await expect(poolCreator.addVersion(
            user0.address,
            govVersion1.address,
            1,
            "version1"
        )).to.be.revertedWith("implementation must be contract");

        var lpVersion2 = await LiquidityPoolFactory.deploy();
        var govVersion2 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion2.address,
            govVersion2.address,
            2,
            "version2"
        );
        const key2 = versionKey(lpVersion2.address, govVersion2.address);
        expect(await poolCreator.getLatestVersion()).to.equal(key2)

        var lpVersion3 = await LiquidityPoolFactory.deploy();
        var govVersion3 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion3.address,
            govVersion3.address,
            2,
            "version3"
        );
        const key3 = versionKey(lpVersion3.address, govVersion3.address);
        expect(await poolCreator.getLatestVersion()).to.equal(key3)

        var result = await poolCreator.getVersion(key1);
        expect(result.liquidityPoolTemplate).to.equal(lpVersion1.address);
        expect(result.governorTemplate).to.equal(govVersion1.address);
        expect(result.compatibility).to.equal(1);

        var result = await poolCreator.getVersion(key2);
        expect(result.liquidityPoolTemplate).to.equal(lpVersion2.address);
        expect(result.governorTemplate).to.equal(govVersion2.address);
        expect(result.compatibility).to.equal(2);

        var result = await poolCreator.getVersion(key3);
        expect(result.liquidityPoolTemplate).to.equal(lpVersion3.address);
        expect(result.governorTemplate).to.equal(govVersion3.address);
        expect(result.compatibility).to.equal(2);

        var result = await poolCreator.listAvailableVersions(0, 10);
        expect(result.length).to.equal(3);
        expect(result[0]).to.equal(key1);
        expect(result[1]).to.equal(key2);
        expect(result[2]).to.equal(key3);

        expect(await poolCreator.isVersionCompatible(key2, key1)).to.be.true;
        expect(await poolCreator.isVersionCompatible(key1, key2)).to.be.false;
        expect(await poolCreator.isVersionCompatible(key3, key2)).to.be.true;
        expect(await poolCreator.isVersionCompatible(key2, key3)).to.be.true;
    })


    it("createLiquidityPoolWith", async () => {
        var lpVersion1 = await LiquidityPoolFactory.deploy();
        var govVersion1 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion1.address,
            govVersion1.address,
            1,
            "version1"
        );
        const key1 = versionKey(lpVersion1.address, govVersion1.address);

        var lpVersion2 = await LiquidityPoolFactory.deploy();
        var govVersion2 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion2.address,
            govVersion2.address,
            2,
            "version2"
        );
        const key2 = versionKey(lpVersion2.address, govVersion2.address);

        const upgradeAdmin = await ethers.getContractAt("IProxyAdmin", await poolCreator.upgradeAdmin());
        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        const deployed1 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(await upgradeAdmin.getProxyImplementation(deployed1[0])).to.equal(lpVersion2.address);
        expect(await upgradeAdmin.getProxyImplementation(deployed1[0])).to.equal(lpVersion2.address);

        const deployed2 = await poolCreator.callStatic.createLiquidityPoolWith(key1, ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.createLiquidityPoolWith(key1, ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(await upgradeAdmin.getProxyImplementation(deployed2[0])).to.equal(lpVersion1.address);
        expect(await upgradeAdmin.getProxyImplementation(deployed2[1])).to.equal(govVersion1.address);
    })

    it("tracer", async () => {
        var lpVersion1 = await LiquidityPoolFactory.deploy();
        var govVersion1 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion1.address,
            govVersion1.address,
            1,
            "version1"
        );
        const key1 = versionKey(lpVersion1.address, govVersion1.address);

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);

        const deployed1 = await poolCreator.connect(user1).callStatic.createLiquidityPool(ctk.address, 18, 996, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.connect(user1).createLiquidityPool(ctk.address, 18, 996, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(1);

        const deployed2 = await poolCreator.connect(user2).callStatic.createLiquidityPool(ctk.address, 18, 997, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.connect(user2).createLiquidityPool(ctk.address, 18, 997, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(2);

        const deployed3 = await poolCreator.connect(user2).callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.connect(user2).createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(await poolCreator.getLiquidityPoolCount()).to.equal(3);

        expect(await poolCreator.isLiquidityPool(deployed1[0])).to.be.true;
        expect(await poolCreator.isLiquidityPool(deployed2[0])).to.be.true;
        expect(await poolCreator.isLiquidityPool(deployed3[0])).to.be.true;
        expect(await poolCreator.isLiquidityPool(user0.address)).to.be.false;

        var result = await poolCreator.listLiquidityPools(0, 100);
        expect(result[0]).to.equal(deployed1[0])
        expect(result[1]).to.equal(deployed2[0])
        expect(result[2]).to.equal(deployed3[0])

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user0.address)).to.equal(0)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user0.address, 0, 100)
        expect(result.length).to.equal(0)

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user1.address)).to.equal(1)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user1.address, 0, 100)
        expect(result.length).to.equal(1)
        expect(result[0]).to.equal(deployed1[0]);

        expect(await poolCreator.getOwnedLiquidityPoolsCountOf(user2.address)).to.equal(2)
        var result = await poolCreator.listLiquidityPoolOwnedBy(user2.address, 0, 100)
        expect(result.length).to.equal(2)
        expect(result[0]).to.equal(deployed2[0]);
        expect(result[1]).to.equal(deployed3[0]);
    })

    it("tracer - 2", async () => {
        var lpVersion1 = await LiquidityPoolFactory.deploy();
        var govVersion1 = await createContract("TestLpGovernor");
        await poolCreator.addVersion(
            lpVersion1.address,
            govVersion1.address,
            1,
            "version1"
        );
        const key1 = versionKey(lpVersion1.address, govVersion1.address);

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        await oracle.setIndexPrice(toWei("1000"), 1000)
        await oracle.setMarkPrice(toWei("1000"), 1000)

        const deployed1 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 996, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.createLiquidityPool(ctk.address, 18, 996, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));

        const liquidityPool1 = await LiquidityPoolFactory.attach(deployed1[0]);
        await liquidityPool1.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )
        await liquidityPool1.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )
        await liquidityPool1.runLiquidityPool();


        const deployed2 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 997, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.createLiquidityPool(ctk.address, 18, 997, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));

        const liquidityPool2 = await LiquidityPoolFactory.attach(deployed2[0]);
        await liquidityPool2.createPerpetual(oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )
        await liquidityPool2.runLiquidityPool();

        var users = [user1, user2, user3];

        for (let i = 0; i < users.length; i++) {
            await ctk.mint(users[i].address, toWei("100"))
            await ctk.connect(users[i]).approve(deployed1[0], toWei("100"))
            await ctk.connect(users[i]).approve(deployed2[0], toWei("100"))
        }

        await liquidityPool1.connect(user1).deposit(0, user1.address, toWei("1"))
        await liquidityPool2.connect(user1).deposit(0, user1.address, toWei("1"))

        await liquidityPool1.connect(user2).deposit(0, user2.address, toWei("1"))
        await liquidityPool1.connect(user2).deposit(1, user2.address, toWei("1"))

        await liquidityPool2.connect(user3).deposit(0, user3.address, toWei("1"))

        var result = await poolCreator.listActiveLiquidityPoolsOf(user1.address, 0, 100);
        expect(result.length).to.equal(2)
        expect(result[0].liquidityPool).to.equal(deployed1[0]);
        expect(result[0].perpetualIndex).to.equal(0);
        expect(result[1].liquidityPool).to.equal(deployed2[0]);
        expect(result[1].perpetualIndex).to.equal(0);

        var result = await poolCreator.listActiveLiquidityPoolsOf(user2.address, 0, 100);
        expect(result.length).to.equal(2)
        expect(result[0].liquidityPool).to.equal(deployed1[0]);
        expect(result[0].perpetualIndex).to.equal(0);
        expect(result[1].liquidityPool).to.equal(deployed1[0]);
        expect(result[1].perpetualIndex).to.equal(1);

        var result = await poolCreator.listActiveLiquidityPoolsOf(user3.address, 0, 100);
        expect(result.length).to.equal(1)
        expect(result[0].liquidityPool).to.equal(deployed2[0]);
        expect(result[0].perpetualIndex).to.equal(0);

    })
})
