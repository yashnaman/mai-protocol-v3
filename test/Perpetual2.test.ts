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
import "./helper";


describe('LiquidityPool', () => {
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

    describe("erc20", async () => {

        let stk;
        let oracle;
        let liquidityPool;

        beforeEach(async () => {
            oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
            const liquidityPoolAddr = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
            await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);

            liquidityPool = await LiquidityPoolFactory.attach(liquidityPoolAddr);
            await liquidityPool.createPerpetual(oracle.address,
                [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05")],
                [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
            )
            await liquidityPool.runLiquidityPool();

            await oracle.setIndexPrice(toWei("1000"), 10000);
            await oracle.setMarkPrice(toWei("1000"), 10000);


            const info = await liquidityPool.getLiquidityPoolInfo();
            stk = (await createFactory("LpGovernor")).attach(info.addresses[3]);
        })

        // it("donateInsuranceFund", async () => {
        //     await ctk.mint(user1.address, toWei("100"));
        //     await ctk.mint(user2.address, toWei("100"));
        //     await ctk.connect(user1).approve(liquidityPool.address, toWei("100"));
        //     await ctk.connect(user2).approve(liquidityPool.address, toWei("100"));

        //     await liquidityPool.connect(user1).donateInsuranceFund(0, toWei("10"));
        //     await liquidityPool.connect(user2).donateInsuranceFund(0, toWei("10"));
        //     var result = await liquidityPool.getPerpetualInfo(0);
        //     expect(result.nums[15]).to.equal(toWei("20"));

        //     await expect(liquidityPool.connect(user1).donateInsuranceFund(0, 0)).to.be.revertedWith("invalid amount")
        // })

        // it("deposit", async () => {
        //     await ctk.mint(user1.address, toWei("100"));
        //     await ctk.connect(user1).approve(liquidityPool.address, toWei("100"));

        //     await liquidityPool.connect(user1).deposit(0, user1.address, toWei("10"));
        //     var result = await liquidityPool.getMarginAccount(0, user1.address);
        //     expect(result.cash).to.equal(toWei("10"));

        //     await expect(liquidityPool.connect(user1).deposit(0, user1.address, 0)).to.be.revertedWith("invalid amount")
        //     await expect(liquidityPool.connect(user2).deposit(0, user1.address, toWei("10"))).to.be.revertedWith("unauthorized caller")

        //     await poolCreator.connect(user1).grantPrivilege(user2.address, 1);
        //     await liquidityPool.connect(user2).deposit(0, user1.address, toWei("10"));
        //     var result = await liquidityPool.getMarginAccount(0, user1.address);
        //     expect(result.cash).to.equal(toWei("20"));

        //     expect(await ctk.balanceOf(user1.address)).to.equal(toWei("80"))
        //     expect(await ctk.balanceOf(user2.address)).to.equal(toWei("0"))
        // })

        // it("withdraw", async () => {
        //     await ctk.mint(user1.address, toWei("100"));
        //     await ctk.connect(user1).approve(liquidityPool.address, toWei("100"));

        //     await liquidityPool.connect(user1).deposit(0, user1.address, toWei("10"));
        //     var result = await liquidityPool.getMarginAccount(0, user1.address);
        //     expect(result.cash).to.equal(toWei("10"));

        //     await liquidityPool.connect(user1).withdraw(0, user1.address, toWei("5"));
        //     var result = await liquidityPool.getMarginAccount(0, user1.address);
        //     expect(result.cash).to.equal(toWei("5"));

        //     await expect(liquidityPool.connect(user1).deposit(0, user1.address, 0)).to.be.revertedWith("invalid amount")
        //     await expect(liquidityPool.connect(user2).deposit(0, user1.address, toWei("5"))).to.be.revertedWith("unauthorized caller")

        //     await poolCreator.connect(user1).grantPrivilege(user2.address, 2);
        //     await liquidityPool.connect(user2).withdraw(0, user1.address, toWei("5"));
        //     var result = await liquidityPool.getMarginAccount(0, user1.address);
        //     expect(result.cash).to.equal(toWei("0"));

        //     expect(await ctk.balanceOf(user1.address)).to.equal(toWei("100"))
        //     expect(await ctk.balanceOf(user2.address)).to.equal(toWei("0"))
        // })

        it("settle", async () => {
            await oracle.setIndexPrice(toWei("1000"), 1000);
            await oracle.setMarkPrice(toWei("1000"), 1000);

            await ctk.mint(user1.address, toWei("1000"));
            await ctk.mint(user2.address, toWei("1000"));
            await ctk.connect(user1).approve(liquidityPool.address, toWei("1000"));
            await ctk.connect(user2).approve(liquidityPool.address, toWei("1000"));

            await liquidityPool.connect(user1).deposit(0, user1.address, toWei("1000"));
            await liquidityPool.connect(user2).addLiquidity(toWei("1000"));

            var now = Math.floor(Date.now() / 1000)
            await liquidityPool.connect(user1).trade(0, user1.address, toWei("1"), toWei("2000"), now + 100000, "0x0000000000000000000000000000000000000000", 0);

            // user +1 amm -1
            await oracle.setIndexPrice(toWei("2000"), 2000);
            await oracle.setMarkPrice(toWei("2000"), 2000);

            await liquidityPool.setEmergencyState(0);
            await liquidityPool.clear(0);
            await liquidityPool.connect(user1).settle(0, user1.address);
            const info = await liquidityPool.getLiquidityPoolInfo();
            await liquidityPool.connect(user2).removeLiquidity(await stk.balanceOf(user2.address));


            console.log(fromWei(await ctk.balanceOf(user1.address)));
            console.log(fromWei(await ctk.balanceOf(liquidityPool.address)));
            console.log(fromWei(await ctk.balanceOf(vault.address)));
            console.log(fromWei(await ctk.balanceOf(user0.address)));
            console.log(fromWei(await ctk.balanceOf(user2.address)));
        })
    });
})

