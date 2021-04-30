const { ethers } = require("hardhat");
import { expect } from "chai";

import "./helper";
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

describe("integration2 - 2 perps. trade with targetLeverage", () => {
    let USE_TARGET_LEVERAGE = 0x8000000;
    let IS_CLOSE_ONLY = 0x80000000;
    
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
            // imr         mmr            operatorfr       lpfr             rebate      penalty         keeper      insur       oi
            [toWei("0.01"), toWei("0.005"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.002"), toWei("0.5"), toWei("0.5"), toWei("4")],
            // alpha        beta1         beta2          frLimit     lev         maxClose       frFactor
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05"), toWei("0.01"), toWei("1")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99"), toWei("1"), toWei("1")],
        )
        await perp.createPerpetual(oracle2.address,
            // imr         mmr            operatorfr       lpfr             rebate      penalty         keeper      insur       oi
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

        // 2x target leverage
        await perp.connect(user1).setTargetLeverage(0, user1.address, toWei("2"));
    });

    it("addLiq + tradeWithLev long 3, short 2, short 2, long 1", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // cash = deposit - 3450 - 3450 * 0.003(fee). so deposit = 1960.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // 10000 - 1960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // 3450 - 3450 * 0.001(fee)
        expect(position).to.equal(toWei("-3"));
        expect(margin).to.equal(toWei("453.45"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        
        // short 2 (partial close)
        await perp.connect(user1).trade(0, user1.address, toWei("-2"), toWei("950"), now + 999999, none, USE_TARGET_LEVERAGE);
        // amm deltaCash = -2100
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -500
        // newCash = oldCash - withdraw + 2100 - 2100 * 0.003(fee). so withdraw = 1093.7
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).approximateBigNumber(toWei("-500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9133.35")); // 8039.65 + 1093.7
        expect(position).to.equal(toWei("1"));
        expect(margin).approximateBigNumber(toWei("500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        // AMM rebalance. margin = 1000 * 1 * 1% = 10
        // amm cash + mark pos. so cash = 10 + 1000 * 1
        // final transferFee, cash += 2100 * 0.001(fee)
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("1012.1")); // rebalance. margin = im + fee
        expect(position).to.equal(toWei("-1"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1343.45")); // rebalance. 1000 + (3453.45 - 2100 + 2100 * 0.001(fee) - 1012.1)
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("5.55")); // operator fee = 2.1
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("5.55")); // vault fee = 2.1

        // short 2 (close all + open)
        await perp.connect(user1).trade(0, user1.address, toWei("-2"), toWei("950"), now + 999999, none, USE_TARGET_LEVERAGE);
        // amm deltaCash = -1984.996757074682502
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = 1500
        // idealMargin = oldCash + deltaCash + deposit - fee + mark newPos.
        // so deposit = 500 - (-500) - (1984...) + 1984... * 0.003 - (-1000) = 20.958233196541545506
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).approximateBigNumber(toWei("1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9112.391766803458454494")); // 9133.35 - deposit
        expect(position).to.equal(toWei("-1"));
        expect(margin).approximateBigNumber(toWei("500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("-970.911760317607819498")); // 1012.1 + amm deltaCash + fee
        expect(position).to.equal(toWei("1"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1343.45")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("7.534996757074682502")); // operator fee = 1.984996757074682502
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("7.534996757074682502")); // vault fee = 1.984996757074682502

        // long 1 (close all)
        await perp.connect(user1).trade(0, user1.address, toWei("1"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        // amm deltaCash = 977.783065493367778000
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).approximateBigNumber(toWei("0"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9631.67535211361057316")); // oldCtk + (oldCash - 977...) - 977... * 0.003
        expect(position).to.equal(toWei("0"));
        expect(margin).approximateBigNumber(toWei("0"));
        expect(isMaintenanceMarginSafe).to.be.true;
        // AMM rebalance. margin = 1000 * 1 * 1% = 10
        // amm cash + mark pos. so cash = 10 + 1000 * 1
        // final transferFee, cash += 2100 * 0.001(fee)
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("0.977783065493367778")); // rebalance. im + fee
        expect(position).to.equal(toWei("0"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1350.321305175759958502")); // rebalance. oldPoolCash + (oldPerpCash + deltaCash) = 1343.45 + (-970... + 977...)
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("8.51277982256805028")); // operator fee = 0.977783065493367778
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("8.51277982256805028")); // vault fee = 0.977783065493367778
    });

    it("deposit + long 3(auto deposit on demand)", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // deposit
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9500")); // oldCtk - 500
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(cash).to.equal(toWei("500"));

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // newCash = oldCash + deposit - 3450 - 3450 * 0.003(fee). so deposit = 1460.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // oldCtk - 1460.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-3"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
    });

    it("short 1 when MM < margin < IM, normal fees", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // newCash = deposit - 3450 - 3450 * 0.003(fee). so deposit = 1960.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // oldCtk - 1960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-3"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        
        // close when MM < margin < IM, normal fees
        await updatePrice(toWei("505"), toWei("1000"))
        await perp.forceToSyncState();
        var { margin, isInitialMarginSafe, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(isInitialMarginSafe).to.be.false;
        expect(isMaintenanceMarginSafe).to.be.true;
        await perp.connect(user1).trade(0, user1.address, toWei("-1"), toWei("500"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isInitialMarginSafe, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = -515.541132467602916841
        // newMargin = newCash + 505 * 2 = 505 * 2 * 0.01. so cash = -999.9
        // newCash = oldCash - withdraw + 515... - 515... * 0.003(fee). so withdraw = 13.894509070200108090477
        expect(cash).to.equal(toWei("-999.9"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8053.544509070200108090")); // oldCtk + withdraw
        expect(position).to.equal(toWei("2"));
        expect(isInitialMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("1020.615541132467602917")); // rebalance. margin = im + fee
        expect(position).to.equal(toWei("-2"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("2917.808867532397083159")); // rebalance. old + (oldCash + deltaCash + fee - cash)
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.965541132467602917")); // operator fee = 0.515541132467602917
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.965541132467602917")); // vault fee = 0.515541132467602917
    });

    it("short 1 when margin < mm, the profit is large enough, normal fees", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // newCash = deposit - 3450 - 3450 * 0.003(fee). so deposit = 1960.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // oldCtk - 1960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // no rebalance, oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-3"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45

        // oracle
        await updatePrice(toWei("501"), toWei("1000"))
        await perp.forceToSyncState();

        // user 2 longs. make a higher price
        await perp.connect(user2).trade(0, user2.address, toWei("2"), toWei("1000"), now + 999999, none, USE_TARGET_LEVERAGE);
        // amm deltaCash = 1070.964429859700685024
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("4525.485394289560385709")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-5"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("4.520964429859700685")); // operator fee = 1.070964429859700685024
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("4.520964429859700685")); // vault fee = 1.070964429859700685024

        // close when margin < MM, but profit is large, normal fees
        var { isMaintenanceMarginSafe, isMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(isMaintenanceMarginSafe).to.be.false;
        expect(isMarginSafe).to.be.true;
        await perp.connect(user1).trade(0, user1.address, toWei("-1"), toWei("500"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isInitialMarginSafe, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = -521.201994206724030199
        // old lev = 501x, margin = 501 * 2 * 1% = cash + 501 * 2
        // cash = oldCash + deltaCash - fee - withdraw. so withdraw = 11.618388224103858109
        expect(cash).to.equal(toWei("-991.98")); // 501 * 2 * 1% - 501 * 2
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8051.268388224103858109")); // + withdraw
        expect(position).to.equal(toWei("2"));
        expect(isInitialMarginSafe).to.be.true;
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("2024.561201994206724030")); // rebalance. margin = im + fee
        expect(position).to.equal(toWei("-4"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("2980.243400082836355510")); // rebalance. old + (oldCash + deltaCash + fee - cash)
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("5.042166424066424715")); // operator fee = 0.52120199420672403
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("5.042166424066424715")); // vault fee = 0.52120199420672403
    });

    it("short 1 when bankrupt (close positions will cause profit), reduced fees", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // newCash = deposit - 3450 - 3450 * 0.003(fee). so deposit = 1960.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // oldCtk - 1960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-3"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        
        // oracle
        await updatePrice(toWei("500"), toWei("1000"))
        await perp.forceToSyncState();

        // close when margin < MM, reduces fees
        var { isMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(isMarginSafe).to.be.false;
        await perp.connect(user1).trade(0, user1.address, toWei("-1"), toWei("500"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isInitialMarginSafe, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = -510.202621119993762015
        // old lev = ∞ (margin balance = 0), fee = 3 * 0.067540373331254005 (13% of normal fees)
        // withdraw = 0
        expect(cash).to.equal(toWei("-990")); // oldCash + deltaCash - fee
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // not change
        expect(position).to.equal(toWei("2"));
        expect(isInitialMarginSafe).to.be.true;
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("2943.314919253337491992")); // no rebalance. old + deltaCash + fee
        expect(position).to.equal(toWei("-2"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.517540373331254004")); // operator fee = 0.067540373331254005
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.517540373331254004")); // vault fee = 0.067540373331254005
    });

    it("short 1 when safe (close positions will cause loss), fees = 0", async () => {
        await perp.runLiquidityPool();

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // poolCash
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("0")); // total collateral of perpetual

        // long 3 (open)
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = 3450
        // margin = cash + positionValue = | positionValue | / 2xLev. so cash = -1500
        // newCash = deposit - 3450 - 3450 * 0.003(fee). so deposit = 1960.35
        expect(cash).to.equal(toWei("-1500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // oldCtk - 1960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("1500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("3453.45")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("-3"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        
        // oracle
        await updatePrice(toWei("506"), toWei("1000"))
        await perp.forceToSyncState();

        // user 2 sells. make a lower price
        await perp.connect(user2).trade(0, user2.address, toWei("-4"), toWei("0"), now + 999999, none, USE_TARGET_LEVERAGE);
        // amm deltaCash = -2043.345318849321722334
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("1412.148026469527599388")); // oldCash + deltaCash + fee
        expect(position).to.equal(toWei("1"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("5.493345318849321722")); // operator fee = 2.043345318849321722
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("5.493345318849321722")); // vault fee = 2.043345318849321722

        // close when margin < MM, reduces fees
        var { isInitialMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(isInitialMarginSafe).to.be.true;
        await perp.connect(user1).trade(0, user1.address, toWei("-1"), toWei("450"), now + 999999, none, USE_TARGET_LEVERAGE);
        var { cash, position, margin, isMarginSafe, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // amm deltaCash = -492.240720624875890864
        // required im = 10.12, margin(after trade) = 4.240720624875890864 < im
        // so withdraw = 0, fee = 0
        expect(cash).to.equal(toWei("-1007.759279375124109136")); // oldCash + deltaCash - fee
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("8039.65")); // not change
        expect(position).to.equal(toWei("2"));
        expect(isMaintenanceMarginSafe).to.be.false;
        expect(isMarginSafe).to.be.true;
        var { cash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(cash).to.equal(toWei("919.907305844651708524")); // no rebalance. old + deltaCash + fee
        expect(position).to.equal(toWei("2"));
        var { intNums } = await perp.getLiquidityPoolInfo();
        expect(intNums[1]).to.equal(toWei("1000")); // no rebalance, not changed
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("5.493345318849321722")); // operator fee = 0
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("5.493345318849321722")); // vault fee = 0
    });
})