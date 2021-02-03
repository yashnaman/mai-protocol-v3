const { ethers } = require("hardhat");
const { expect } = require("chai");
import { BigNumber as BN } from "ethers";
import {
    toWei,
    createContract,
    createLiquidityPoolFactory
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
        var lpTokenTemplate = await createContract("ShareToken");
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

        const liquidityPoolAddr = await creator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await creator.createLiquidityPool(ctk.address, 18, false, 998);


        const LiquidityPoolFactoryV2 = await createLiquidityPoolFactory("LiquidityPoolRelayable");
        const liquidityPoolV2Template = await LiquidityPoolFactoryV2.deploy();
        const liquidityPool = await LiquidityPoolFactoryV2.attach(liquidityPoolAddr);

        // oracle
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await liquidityPool.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await liquidityPool.runLiquidityPool();

        // console.log(liquidityPoolTemplate.address)

        // expect(await govTemplate.getImplementation(liquidityPool.address)).to.equal(liquidityPoolTemplate.address);
        // await expect(liquidityPool.L2_DOMAIN_NAME()).to.be.revertedWith("");

        await govTemplate.functionCall(liquidityPool.address, "0x675a0aa5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000470de4df820000000000000000000000000000000000000000000000000000002386f26fc1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001f438daa06000000000000000000000000000000000000000000000000000058d15e1762800000000000000000000000000000000000000000000000000000001c6bf526340000000000000000000000000000000000000000000000000000001c6bf5263400000000000000000000000000000000000000000000000000003782dace9d9000000000000000000000000000000000000000000000000003635c9adc5dea00000", 0);
        // expect(await govTemplate.getImplementation(liquidityPool.address)).to.equal(liquidityPoolV2Template.address);

        // expect(await liquidityPool.L2_DOMAIN_NAME()).to.equal("Mai L2 Call");

        // await govTemplate.functionCall(liquidityPool.address, "0xd73b5e4200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", 0);


        // const tx = await liquidityPool.setPerpetualBaseParameter(
        //     0,
        //     [toWei("0.02"), toWei("0.01"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.0005"), toWei("0.0005"), toWei("0.25"), toWei("1000")],
        // );

        // console.log(tx);
    })
})
