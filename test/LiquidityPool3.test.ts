import BigNumber from 'bignumber.js';
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
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(perpTemplate.address, 0, "initial version");
    });

    it("createPerpetual - address", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const liquidityPoolAddr1 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        // nonce +1
        await ctk.approve(liquidityPoolAddr1, 1000);
        const liquidityPoolAddr2 = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        expect(liquidityPoolAddr1).to.equal(liquidityPoolAddr2);
    })

    it("createPerpetual - fastCreation disable", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const liquidityPoolAddr = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);

        const liquidityPool = await LiquidityPoolFactory.attach(liquidityPoolAddr);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();
        await expect(liquidityPool.runLiquidityPool()).to.be.revertedWith("already running")

        await expect(liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )).to.be.revertedWith("only governor can create perpetual")
    })

    it("createPerpetual - fastCreation enabled", async () => {
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        const liquidityPoolAddr = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, true, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, true, 998);

        const liquidityPool = await LiquidityPoolFactory.attach(liquidityPoolAddr);
        await liquidityPool.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();
        await expect(liquidityPool.runLiquidityPool()).to.be.revertedWith("already running")

        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await liquidityPool.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), 1, toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        );
    })

})

