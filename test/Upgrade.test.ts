const { ethers } = require("hardhat");
const { expect } = require("chai");
import { BigNumber as BN } from "ethers";
import {
    toWei,
    createContract,
    createLiquidityPoolFactory,
    createFactory
} from "../scripts/utils";

describe("upgrade", () => {

    it("main", async () => {
        // users
        const accounts = await ethers.getSigners();
        const user0 = accounts[0];
        const vault = accounts[9];

        // create components
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("TestGovernor");
        var govTemplate = await createContract("TestGovernor");
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
        await symbol.addWhitelistedFactory(creator.address);
        const LiquidityPoolFactory = await createLiquidityPoolFactory();
        const liquidityPoolTemplate = await LiquidityPoolFactory.deploy();
        await creator.addVersion(liquidityPoolTemplate.address, 0, "initial version");

        const liquidityPoolAddr = await creator.callStatic.createLiquidityPool(ctk.address, 18, false, 998, toWei("1000000"));
        await creator.createLiquidityPool(ctk.address, 18, false, 998, toWei("1000000"));

        const liquidityPool = await LiquidityPoolFactory.attach(liquidityPoolAddr);

        // oracle
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();


        var { addresses } = await liquidityPool.getLiquidityPoolInfo();
        const governor = (await createFactory("TestGovernor")).attach(addresses[3]);

        const liquidityPoolV2Template = await LiquidityPoolFactory.deploy();
        await creator.addVersion(liquidityPoolV2Template.address, 1, "version2");
        await governor.upgradeTo(liquidityPool.address, liquidityPoolV2Template.address);

        // const liquidityPoolV3Template = await LiquidityPoolFactory.deploy();
        // await creator.addVersion(liquidityPoolV3Template.address, 0, "version3");
        // expect(await governor.upgradeTo(liquidityPool.address, liquidityPoolV3Template.address)).to.be.revertedWith("incompatible implementation")

        // const liquidityPoolV4Template = await LiquidityPoolFactory.deploy();
        // expect(await governor.upgradeTo(liquidityPool.address, liquidityPoolV4Template.address)).to.be.revertedWith("uncertificated implementation")
    })
})
