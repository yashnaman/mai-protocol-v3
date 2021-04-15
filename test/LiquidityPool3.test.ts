const { ethers } = require("hardhat");
import { expect, use } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createLiquidityPoolFactory,
} from '../scripts/utils';
import "./helper";


describe('LiquidityPool3', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let vault;
    let ctk;
    let poolCreator;
    let LiquidityPoolFactory;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        vault = accounts[9];
    })

    beforeEach(async () => {
        LiquidityPoolFactory = await createLiquidityPoolFactory();
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        var govTemplate = await createContract("TestGovernor");
        poolCreator = await createContract("PoolCreator");
        await poolCreator.initialize(
            weth.address,
            symbol.address,
            vault.address,
            toWei("0.001"),
            vault.address
        )
        await poolCreator.addVersion(perpTemplate.address, govTemplate.address, 0, "initial version");
        await symbol.addWhitelistedFactory(poolCreator.address);
    });

    it("createPerpetual - address", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const deplpyed1 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await ctk.approve(deplpyed1[0], 1000);
        const deplpyed2 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        expect(deplpyed1[0]).to.equal(deplpyed2[0]);
        expect(deplpyed1[1]).to.equal(deplpyed2[1]);
    })

    it("createPerpetual - fastCreation disable", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const deployed = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));
        await poolCreator.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]));

        const liquidityPool = await LiquidityPoolFactory.attach(deployed[0]);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();
        await expect(liquidityPool.runLiquidityPool()).to.be.revertedWith("already running")

        await expect(liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )).to.be.revertedWith("only governor can create perpetual")
    })

    it("createPerpetual - fastCreation enabled", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const deployed = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [true, toWei("1000000")]));
        await poolCreator.createLiquidityPool(ctk.address, 18, 998, ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [true, toWei("1000000")]));

        const liquidityPool = await LiquidityPoolFactory.attach(deployed[0]);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();
        await expect(liquidityPool.runLiquidityPool()).to.be.revertedWith("already running")

        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await liquidityPool.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        );
    })

})

