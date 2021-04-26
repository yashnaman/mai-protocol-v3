const { ethers } = require("hardhat");
import { expect } from "chai";

import "./helper";
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

describe("integration2", () => {

    let user0;
    let user1;
    let user2;
    let user3;
    let vault;
    const none = "0x0000000000000000000000000000000000000000";
    let perp;
    let ctk;
    let stk;
    let oracle1;
    let oracle2;
    let updatePrice = async (price1, price2) => {
        let now = Math.floor(Date.now() / 1000);
        await oracle1.setMarkPrice(price1, now);
        await oracle1.setIndexPrice(price1, now);
        await oracle2.setMarkPrice(price2, now);
        await oracle2.setIndexPrice(price2, now);
    }

    beforeEach(async () => {
        // users
        const accounts = await ethers.getSigners();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        vault = accounts[9];
        const LiquidityPoolFactory = await createLiquidityPoolFactory();

        // create components
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        var govTemplate = await createContract("TestLpGovernor");
        var poolCreator = await createContract("PoolCreator");
        await poolCreator.initialize(
            weth.address,
            symbol.address,
            vault.address,
            toWei("0.001"),
            vault.address
        )
        await poolCreator.addVersion(perpTemplate.address, govTemplate.address, 0, "initial version");
        await symbol.addWhitelistedFactory(poolCreator.address);

        const { liquidityPool, governor } = await poolCreator.callStatic.createLiquidityPool(
            ctk.address,
            18,
            998,
            ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]),
        );
        await poolCreator.createLiquidityPool(
            ctk.address,
            18,
            998,
            ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")]),
        );
        perp = await LiquidityPoolFactory.attach(liquidityPool);


        // oracle
        oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await updatePrice(toWei("1000"), toWei("1000"))

        // create perpetual
        await perp.createPerpetual(oracle1.address,
            [toWei("0.01"), toWei("0.005"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.002"), toWei("0.5"), toWei("0.5"), toWei("4")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )
        await perp.createPerpetual(oracle2.address,
            [toWei("0.01"), toWei("0.005"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.002"), toWei("0.5"), toWei("0.5"), toWei("4")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )

        // share token
        const info = await perp.getLiquidityPoolInfo();
        stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.mint(user3.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));
        await ctk.connect(user3).approve(perp.address, toWei("100000"));
    });

    it("normal case", async () => {
        await perp.runLiquidityPool();
        // deposit
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9500"));
        await perp.connect(user1).deposit(1, user1.address, toWei("100"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9400"));
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).to.equal(toWei("500"));
        expect(position).to.equal(toWei("0"));
        expect(margin).to.equal(toWei("500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("500")); // total collateral of perpetual
        expect(nums[31]).to.equal(toWei("0")); // open interest of perpetual
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(cash).to.equal(toWei("100"));
        expect(position).to.equal(toWei("0"));
        expect(margin).to.equal(toWei("100"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("100")); // total collateral of perpetual
        expect(nums[31]).to.equal(toWei("0")); // open interest of perpetual

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await stk.balanceOf(user2.address)).to.equal(toWei("1000")); // first time stk amount = ctk amount
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000"));
        var { poolMargin } = await perp.getPoolMargin();
        expect(poolMargin).to.equal(toWei("1000"));
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("500")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("100")); // total collateral of perpetual

        // trade
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).to.equal(toWei("-2960.35")); // 500 - 3450 - 3450 * 0.003(fee) = -2960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("39.65"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3450")); // lp fee = 3.45 (x), 3450 + 3.45 = 3453.45
        expect(position).to.equal(toWei("-3"));
        expect(margin).to.equal(toWei("450"));
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        var { poolMargin } = await perp.getPoolMargin();
        // expect(poolMargin).approximateBigNumber(toWei("1006.241056113061240366"));
        expect(poolMargin).approximateBigNumber(toWei("1006.241056113061240366"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1003.45")); // no rebalance, pool cash doesn't change
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("500")); // total collateral of perpetual
        expect(nums[31]).to.equal(toWei("3")); // open interest of perpetual

        await perp.connect(user1).trade(1, user1.address, toWei("-1"), toWei("950"), now + 999999, none, 0);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(cash).approximateBigNumber(toWei("1047.459186993858006293")); // 100 - 950.310117345895693374 - 950.310117345895693374 * 0.003(fee) = 1047.4591869938580062938859841
        expect(position).to.equal(toWei("-1"));
        expect(margin).approximateBigNumber(toWei("47.459186993858006293"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(1, perp.address); // AMM account
        expect(cash).approximateBigNumber(toWei("-950.310117345895693374")); // lp fee = 0.950310117345895693 => pool
        expect(position).to.equal(toWei("1"));
        expect(margin).approximateBigNumber(toWei("49.689882654104306627"));
        expect(await ctk.balanceOf(user0.address)).approximateBigNumber(toWei("4.400310117345895693")); // operator fee = 0.950310117345895693 + 3.45
        expect(await ctk.balanceOf(vault.address)).approximateBigNumber(toWei("4.400310117345895693")); // vault fee = 0.950310117345895693 + 3.45
        var { poolMargin } = await perp.getPoolMargin();
        expect(poolMargin).approximateBigNumber(toWei("1008.115061430074958062"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1004.400310117345895693")); // 1000 + 3.45 + 0.950310117345895693
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).approximateBigNumber(toWei("100")); // total collateral of perpetual, 100 - 0.950310117345895693(operator fee) - 0.950310117345895693(vault fee)
        expect(nums[31]).to.equal(toWei("1")); // open interest of perpetual

        // remove liquidity
        await perp.connect(user2).removeLiquidity(toWei("200"), 0, true);
        expect(await stk.balanceOf(user2.address)).to.equal(toWei("800"));
        expect(await ctk.balanceOf(user2.address)).approximateBigNumber(toWei("9077.629229450671180548"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).approximateBigNumber(toWei("922.37077054932881945"));
        var { poolMargin } = await perp.getPoolMargin();
        expect(poolMargin).approximateBigNumber(toWei("806.492049144059966449"));
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("493.1")); // total collateral of perpetual, remove liquidity don't change collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).approximateBigNumber(toWei("98.09937976530821")); // total collateral of perpetual, remove liquidity don't change collateral of perpetual

        // withdraw
        await perp.connect(user1).withdraw(0, user1.address, toWei("9"), true);
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9409"));
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).to.equal(toWei("-2969.35")); // -2960.35 - 9 = -2969.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("30.65")); // 39.65 - 9 = 30.65
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account, rebalance, pool margin and available cash in perpetual are both changed
        expect(cash).approximateBigNumber(toWei("3030"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).approximateBigNumber(toWei("1345.82077054932881945"));

        await perp.connect(user1).withdraw(1, user1.address, toWei("37"), true);
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9446"));
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(cash).approximateBigNumber(toWei("1010.459186993858006293")); // 1047.4591869938580062938859841 - 37 = 1010.4591869938580062938859841
        expect(position).to.equal(toWei("-1"));
        expect(margin).approximateBigNumber(toWei("10.459186993858006293")); // 47.459186993858006293 - 37 = 10.459186993858006293
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(1, perp.address); // AMM account, rebalance, pool margin and available cash in perpetual are both changed
        expect(cash).approximateBigNumber(toWei("-990"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).approximateBigNumber(toWei("1386.4609633207790218"));

        // liquidate by AMM
        await expect(perp.connect(user3).liquidateByAMM(0, user1.address)).to.be.revertedWith("trader is safe");
        await updatePrice(toWei("994"), toWei("1000"));
        // liquidate price clip to discount: 994 * (1 + 0.05)
        // penalty = mark * amount * penalty rate = 994 * 3 * 0.002
        // keeper gas reward = 0.5
        await perp.connect(user3).liquidateByAMM(0, user1.address);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // expect(cash).to.equal(toWei("155.286")); // -2969.35 + 994 * (1 + 0.05) * 3 - 994 * 3 * 0.002 - 0.5
        expect(cash).to.equal(toWei("152.304")); // -2969.35 + 994 * (1 + 0.05) * 3 - 994 * 3 * 0.002 - 0.5 - 994 * 3 * 0.001
        expect(position).to.equal(0);
        expect(margin).to.equal(toWei("152.304"));
        expect(isMaintenanceMarginSafe).to.be.true;
        expect(await ctk.balanceOf(user3.address)).to.equal(toWei("10000.5")); // keeper gas reward = 0.5
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[31]).to.equal(toWei("0")); // open interest of perpetual
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address);
        expect(cash).approximateBigNumber(toWei("-98.118"));
        expect(position).to.equal(0);
        expect(margin).approximateBigNumber(toWei("-98.118"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).approximateBigNumber(toWei("1386.4609633207790218")); // not change
        expect(intNums[3]).to.equal(toWei("2.982")); // insurance fund = 994 * 3 * 0.002 * 0.5
        var { poolMargin } = await perp.getPoolMargin();
        expect(poolMargin).approximateBigNumber(toWei("1258.616813582084875711"));

        // liquidate by trader
        await perp.connect(user3).deposit(1, user3.address, toWei("500"));
        await expect(perp.connect(user3).liquidateByTrader(1, user1.address, toWei("-1"), toWei("999"), now + 999999)).to.be.revertedWith("trader is safe");
        await updatePrice(toWei("994"), toWei("1006"));
        // liquidate price is mark price = 1006
        // penalty = 1006 * 1 * 0.002 = 2.012
        await perp.connect(user3).liquidateByTrader(1, user1.address, toWei("-1"), toWei("1006"), now + 999999);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(cash).approximateBigNumber(toWei("1.441186993858006293")); // 1010.459186993858006293 - 1006 * 1 - 1006 * 1 * 0.002 - 1.006
        expect(position).to.equal(0);
        expect(margin).approximateBigNumber(toWei("1.441186993858006293"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[31]).to.equal(toWei("1")); // open interest of perpetual
        var { cash, position, margin } = await perp.getMarginAccount(1, user3.address);
        expect(cash).approximateBigNumber(toWei("1507.006")); // 500 + 1006 + 1006 * 1 * 0.002 * 0.5
        expect(position).to.equal(toWei("-1"));
        expect(margin).approximateBigNumber(toWei("501.006"));
        var { cash, position, margin } = await perp.getMarginAccount(1, perp.address);
        expect(cash).to.equal(toWei("-990"));
        expect(position).to.equal(toWei("1"));
        expect(margin).approximateBigNumber(toWei("16"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[3]).to.equal(toWei("3.988")); // insurance fund = 2.982 + 1006 * 1 * 0.002 * 0.5
        expect(intNums[1]).approximateBigNumber(toWei("1386.4609633207790218")); // not change
        var { poolMargin } = await perp.getPoolMargin();
        expect(poolMargin).approximateBigNumber(toWei("1264.320026942584698681"));
    })

    it("deposit more than balance", async () => {
        await perp.runLiquidityPool();
        await expect(perp.connect(user1).deposit(0, user1.address, toWei("10001"))).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    })

    it("deposit when not NORMAL", async () => {
        await expect(perp.connect(user1).deposit(0, user1.address, toWei("500"))).to.be.revertedWith("perpetual should be in NORMAL state");
    })

    it("add liquidity more than balance", async () => {
        await perp.runLiquidityPool();
        await expect(perp.addLiquidity(toWei("100001"))).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    })

    it("add liquidity when not running", async () => {
        await expect(perp.addLiquidity(toWei("1000"))).to.be.revertedWith("pool is not running");
    })

    it("trade when not authorized", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        await expect(perp.connect(user2).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("unauthorized caller");
    })

    it("trade when market closed", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        oracle1.setMarketClosed(true);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("market is closed now");
    })

    it("trade when market terminated", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        oracle1.setTerminated(true);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("perpetual should be in NORMAL state");
    })

    it("trade when invalid close-only amount", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 2147483648)).to.be.revertedWith("trader has no position to close");
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 2147483648)).to.be.revertedWith("trader must be close only");
    })

    it("trade when invalid limit price", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1149"), now + 999999, none, 0)).to.be.revertedWith("price exceeds limit");
        await expect(perp.connect(user1).trade(0, user1.address, toWei("-3"), toWei("851"), now + 999999, none, 0)).to.be.revertedWith("price exceeds limit");
    })

    it("trade when trader unsafe", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("490"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        // open position, initial margin unsafe
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("margin unsafe");
        // close position, margin unsafe
        await perp.connect(user1).deposit(0, user1.address, toWei("10"));
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0);
        await updatePrice(toWei("939"), toWei("1000"));
        await expect(perp.connect(user1).trade(0, user1.address, toWei("-3"), toWei("851"), now + 999999, none, 0)).to.be.revertedWith("margin unsafe");
    })

    it("trade when exceed open interest limit", async () => {
        await perp.runLiquidityPool();
        await perp.connect(user1).deposit(0, user1.address, toWei("10000"));
        await perp.connect(user2).addLiquidity(toWei("1000"));
        let now = Math.floor(Date.now() / 1000);
        await expect(perp.connect(user1).trade(0, user1.address, toWei("4.3"), toWei("999999"), now + 999999, none, 0)).to.be.revertedWith("open interest exceeds limit");
    })
})