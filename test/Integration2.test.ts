const { ethers } = require("hardhat");
import { expect } from "chai";

import "./helper";
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

describe("integration", () => {

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

        // create perp
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
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
        const LiquidityPoolFactory = await createLiquidityPoolFactory();
        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");
        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await maker.createLiquidityPool(ctk.address, 18, false, 998);
        perp = await LiquidityPoolFactory.attach(perpAddr);
        // oracle
        oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await updatePrice(toWei("1000"), toWei("1000"))

        // create perpetual
        await perp.createPerpetual(oracle1.address,
            [toWei("0.01"), toWei("0.005"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.002"), toWei("0.5"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )
        await perp.createPerpetual(oracle2.address,
            [toWei("0.01"), toWei("0.005"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.002"), toWei("0.5"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        // share token
        const info = await perp.getLiquidityPoolInfo();
        stk = await (await createFactory("LpGovernor")).attach(info[2][4]);

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        await ctk.connect(user1).approve(perp.address, toWei("100000"));
        await ctk.connect(user2).approve(perp.address, toWei("100000"));
    });

    it("normal case", async () => {
        await perp.runLiquidityPool();
        // deposit
        await perp.connect(user1).deposit(0, user1.address, toWei("500"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9500"));
        await perp.connect(user1).deposit(1, user1.address, toWei("100"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9400"));
        var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(availableCash).to.equal(toWei("500"));
        expect(position).to.equal(toWei("0"));
        expect(margin).to.equal(toWei("500"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("500")); // total collateral of perpetual
        var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(availableCash).to.equal(toWei("100"));
        expect(position).to.equal(toWei("0"));
        expect(margin).to.equal(toWei("100"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("100")); // total collateral of perpetual

        // add liquidity
        await perp.connect(user2).addLiquidity(toWei("1000"));
        expect(await stk.balanceOf(user2.address)).to.equal(toWei("1000")); // first time stk amount = ctk amount
        expect(await ctk.balanceOf(user2.address)).to.equal(toWei("9000"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).to.equal(toWei("1000"));
        expect(await perp.getPoolMargin()).to.equal(toWei("1000"));
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("500")); // total collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).to.equal(toWei("100")); // total collateral of perpetual

        // trade
        let now = Math.floor(Date.now() / 1000);
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0);
        var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(availableCash).to.equal(toWei("-2960.35")); // 500 - 3450 - 3450 * 0.003(fee) = -2960.35
        expect(position).to.equal(toWei("3"));
        expect(margin).to.equal(toWei("39.65"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { availableCash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account
        expect(availableCash).to.equal(toWei("3453.45")); // lp fee = 3.45, 3450 + 3.45 = 3453.45
        expect(position).to.equal(toWei("-3"));
        expect(margin).to.equal(toWei("453.45"));
        expect(await ctk.balanceOf(user0.address)).to.equal(toWei("3.45")); // operator fee = 3.45
        expect(await ctk.balanceOf(vault.address)).to.equal(toWei("3.45")); // vault fee = 3.45
        expect(await perp.getPoolMargin()).approximateBigNumber(toWei("1006.241056113061240366"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).to.equal(toWei("1000")); // no rebalance, pool cash doesn't change
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("493.1")); // total collateral of perpetual, 500 - 3.45(operator fee) - 3.45(vault fee)

        await perp.connect(user1).trade(1, user1.address, toWei("-1"), toWei("950"), now + 999999, none, 0);
        var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(1, user1.address);
        expect(availableCash).approximateBigNumber(toWei("1047.459186993858006293")); // 100 - 950.310117345895693374 - 950.310117345895693374 * 0.003(fee) = 1047.4591869938580062938859841
        expect(position).to.equal(toWei("-1"));
        expect(margin).approximateBigNumber(toWei("47.459186993858006293"));
        expect(isMaintenanceMarginSafe).to.be.true;
        var { availableCash, position, margin } = await perp.getMarginAccount(1, perp.address); // AMM account
        expect(availableCash).approximateBigNumber(toWei("-949.35980722854979768")); // lp fee = 950.310117345895693374 * 0.001, -950.310117345895693374 + 950.310117345895693374 * 0.001 = -949.359807228549797680626
        expect(position).to.equal(toWei("1"));
        expect(margin).approximateBigNumber(toWei("50.64019277145020232"));
        expect(await ctk.balanceOf(user0.address)).approximateBigNumber(toWei("4.400310117345895693")); // operator fee = 0.950310117345895693 + 3.45
        expect(await ctk.balanceOf(vault.address)).approximateBigNumber(toWei("4.400310117345895693")); // vault fee = 0.950310117345895693 + 3.45
        expect(await perp.getPoolMargin()).approximateBigNumber(toWei("1008.115061430074958062"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).to.equal(toWei("1000")); // no rebalance, pool cash doesn't change
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).approximateBigNumber(toWei("98.09937976530821")); // total collateral of perpetual, 100 - 0.950310117345895693(operator fee) - 0.950310117345895693(vault fee)

        // remove liquidity
        await perp.connect(user2).removeLiquidity(toWei("200"));
        expect(await stk.balanceOf(user2.address)).to.equal(toWei("800"));
        expect(await ctk.balanceOf(user2.address)).approximateBigNumber(toWei("9077.629229450671180548"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).approximateBigNumber(toWei("922.37077054932881945"));
        expect(await perp.getPoolMargin()).approximateBigNumber(toWei("806.492049144059966449"));
        var { nums } = await perp.getPerpetualInfo(0);
        expect(nums[0]).to.equal(toWei("493.1")); // total collateral of perpetual, remove liquidity don't change collateral of perpetual
        var { nums } = await perp.getPerpetualInfo(1);
        expect(nums[0]).approximateBigNumber(toWei("98.09937976530821")); // total collateral of perpetual, remove liquidity don't change collateral of perpetual

        // withdraw
        await perp.connect(user1).withdraw(0, user1.address, toWei("9"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9409"));
        var { availableCash, position, margin } = await perp.getMarginAccount(0, perp.address); // AMM account, rebalance, pool margin and available cash in perpetual are both changed
        expect(availableCash).approximateBigNumber(toWei("3030"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).approximateBigNumber(toWei("1345.82077054932881945"));

        await perp.connect(user1).withdraw(1, user1.address, toWei("37"));
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("9446"));
        var { availableCash, position, margin } = await perp.getMarginAccount(1, perp.address); // AMM account, rebalance, pool margin and available cash in perpetual are both changed
        expect(availableCash).approximateBigNumber(toWei("-990"));
        var { poolCash } = await perp.getLiquidityPoolInfo();
        expect(poolCash).approximateBigNumber(toWei("1386.4609633207790218"));

        /*
        // var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
        await updatePrice(toWei("100"))
        await perp.connect(user1).forceToSyncState();

        // var { availableCash, position, margin, isMaintenanceMarginSafe, _ } = await perp.getMarginAccount(0, user1.address);
        // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
        // var { deltaCash } = await perp.queryTradeWithAMM(0, toWei("0").sub(position))
        // console.log(deltaCash.add(margin))

        await perp.connect(user2).donateInsuranceFund(0, toWei("1000"))
        await perp.connect(user3).liquidateByAMM(0, user1.address);
        var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        expect(availableCash).to.equal(0);
        expect(position).to.equal(0);
        // console.log("cash:", fromWei(availableCash), "position:", fromWei(position), "margin:", fromWei(margin), "isSafe:", isMaintenanceMarginSafe);
        */
    })

    it("deposit more than balance", async () => {
        await perp.runLiquidityPool();
        await expect(perp.connect(user1).deposit(0, user1.address, toWei("10001"))).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    })

    it("deposit when not NORMAL", async () => {
        await expect(perp.connect(user1).deposit(0, user1.address, toWei("500"))).to.be.revertedWith("operation is disallowed now");
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
        await expect(perp.connect(user2).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("unauthorized operation");
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
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("market is closed now");
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
        await expect(perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0)).to.be.revertedWith("insufficient margin for fee");
        // close position, margin unsafe
        await perp.connect(user1).deposit(0, user1.address, toWei("10"));
        await perp.connect(user1).trade(0, user1.address, toWei("3"), toWei("1150"), now + 999999, none, 0);
        await updatePrice(toWei("939"), toWei("1000"));
        //perp.connect(user1).trade(0, user1.address, toWei("-3"), toWei("851"), now + 999999, none, 0);
        //var { availableCash, position, margin, isMaintenanceMarginSafe } = await perp.getMarginAccount(0, user1.address);
        //console.log(position.toString(), margin.toString());
        await expect(perp.connect(user1).trade(0, user1.address, toWei("-3"), toWei("851"), now + 999999, none, 0)).to.be.revertedWith("margin unsafe");
    })
})
