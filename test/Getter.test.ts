const { ethers } = require("hardhat");
const { expect } = require("chai");
import { BigNumber as BN } from "ethers";
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

describe("Getter", () => {

    it("main", async () => {
        // users
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
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("LpGovernor");
        var maker = await createContract(
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
        await symbol.addWhitelistedFactory(maker.address);
        var LiquidityPoolFactory = await createLiquidityPoolFactory();
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);

        const perp = await LiquidityPoolFactory.attach(perpAddr);


        // oracle
        let oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let oracle4 = await createContract("OracleWrapper", ["USD", "ETH"]);
        let updatePrice = async (price1, price2, price3, price4) => {
            let now = Math.floor(Date.now() / 1000);
            await oracle1.setMarkPrice(price1, now);
            await oracle1.setIndexPrice(price1, now);
            await oracle2.setMarkPrice(price2, now);
            await oracle2.setIndexPrice(price2, now);
            await oracle3.setMarkPrice(price3, now);
            await oracle3.setIndexPrice(price3, now);
            await oracle4.setMarkPrice(price4, now);
            await oracle4.setIndexPrice(price4, now);
        }
        await updatePrice(toWei("500"), toWei("500"), toWei("500"), toWei("500"))


        await perp.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )

        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await perp.createPerpetual(oracle3.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )
        await perp.createPerpetual(oracle4.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000"), toWei("1")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05"), toWei("0.01")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1")],
        )

        await perp.runLiquidityPool();

        // overview
        const info = await perp.getLiquidityPoolInfo();

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));

        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));

        // deposit
        perp.connect(user1).deposit(0, user1.address, toWei("100"));
        perp.connect(user2).deposit(0, user1.address, toWei("100"));

        // console.log(await perp.listActiveAccounts(0, 0, 0));
        console.log(await perp.listActiveAccounts(0, 0, 1));
        console.log(await perp.listActiveAccounts(0, 0, 2));
        console.log(await perp.listActiveAccounts(0, 0, 3));
        console.log(await perp.listActiveAccounts(0, 0, 4));
    })
})
