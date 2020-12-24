const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

describe('Settlement', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let oracle;
    let ctk;
    let settlement;
    let TestSettlement;

    beforeEach(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        oracle = await createContract("OracleWrapper", ["CTK", "UDA"]);
        const CollateralModule = await createContract("CollateralModule")
        const OracleModule = await createContract("OracleModule")
        const ParameterModule = await createContract("ParameterModule");
        const PerpetualModule = await createContract("PerpetualModule", [], { ParameterModule });
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule });
        const AMMModule = await createContract("AMMModule", [], { CollateralModule });
        const FundingModule = await createContract("FundingModule", [], { AMMModule });
        const SettlementModule = await createContract("SettlementModule", [], { LiquidityPoolModule, CollateralModule });
        TestSettlement = await createFactory("TestSettlement", { ParameterModule, PerpetualModule, FundingModule, SettlementModule, OracleModule });
        settlement = await TestSettlement.deploy();
        await settlement.createPerpetual(
            oracle.address,
            // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
            [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
        await settlement.setCollateral(ctk.address);
    })

    async function printSettleState(perpIndex) {
        const { left, total } = await settlement.getClearProgress(perpIndex);
        const a = await settlement.totalMarginWithoutPosition(0);
        const b = await settlement.totalMarginWithPosition(0);
        const c = await settlement.redemptionRateWithoutPosition(0);
        const d = await settlement.redemptionRateWithPosition(0);
        console.table([
            ["progress", `${left} / ${total}`],
            ["total margin (no pos)", fromWei(a)],
            ["total margin (with pos)", fromWei(b)],
            ["redemption rate (no pos)", fromWei(c)],
            ["redemption rate (with pos)", fromWei(d)],
        ])
    }

    it("freeze price ", async () => {
        var now = Math.floor(Date.now() / 1000);

        await settlement.initializeMarginAccount(0, user1.address, toWei("0"), toWei("1"));
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);
        expect(await settlement.callStatic.getMargin(0, user1.address)).to.equal(toWei("500"));

        await oracle.setIndexPrice(toWei("400"), now);
        await oracle.setMarkPrice(toWei("400"), now);
        expect(await settlement.callStatic.getMargin(0, user1.address)).to.equal(toWei("400"));

        await oracle.setIndexPrice(toWei("600"), now);
        await oracle.setMarkPrice(toWei("600"), now);
        expect(await settlement.callStatic.getMargin(0, user1.address)).to.equal(toWei("600"));

        await settlement.setEmergency(0);
        expect(await settlement.callStatic.getMargin(0, user1.address)).to.equal(toWei("600"));
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);
        expect(await settlement.callStatic.getMargin(0, user1.address)).to.equal(toWei("600"));
    })

    it("clear account", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await settlement.initializeMarginAccount(0, user1.address, toWei("100"), toWei("0.1")); // 100 + 50
        await settlement.initializeMarginAccount(0, user2.address, toWei("200"), toWei("0.2")); // 200 + 100
        await settlement.initializeMarginAccount(0, user3.address, toWei("300"), toWei("0.3")); // 300 + 150

        await settlement.registerActiveAccount(0, user1.address);
        await settlement.registerActiveAccount(0, user2.address);
        await settlement.registerActiveAccount(0, user3.address);

        await settlement.setEmergency(0);

        var { left, total } = await settlement.getClearProgress(0);
        expect(left).to.equal(3);
        expect(total).to.equal(3);

        // await expect(settlement.clear(0)).to.be.revertedWith("trader is invalid");
        await settlement.clear(0);
        var { left, total } = await settlement.getClearProgress(0);
        expect(left).to.equal(2);
        expect(total).to.equal(3);

        await settlement.clear(0);
        var { left, total } = await settlement.getClearProgress(0);
        expect(left).to.equal(1);
        expect(total).to.equal(3);

        await settlement.clear(0);
        var { left, total } = await settlement.getClearProgress(0);
        expect(left).to.equal(0);
        expect(total).to.equal(3);

        await expect(settlement.clear(0)).to.be.revertedWith("operation is disallowed now");
    })

    it("settle and withdraw", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await settlement.setPerpetualCollateralAmount(0, toWei("175"));

        await settlement.initializeMarginAccount(0, user1.address, toWei("100"), toWei("0"));   // 100 + nopos
        await settlement.initializeMarginAccount(0, user2.address, toWei("100"), toWei("0.1")); // 100 +  50
        await settlement.initializeMarginAccount(0, user3.address, toWei("0"), toWei("0.2"));   //   0 + 100
        await settlement.registerActiveAccount(0, user1.address);
        await settlement.registerActiveAccount(0, user2.address);
        await settlement.registerActiveAccount(0, user3.address);

        await settlement.setEmergency(0);
        await settlement.clear(0);
        await settlement.clear(0);
        await settlement.clear(0);

        await printSettleState(0);

        expect(await settlement.redemptionRateWithoutPosition(0)).to.equal(toWei("1"));
        expect(await settlement.redemptionRateWithPosition(0)).to.equal(toWei("0.3"));

        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user1.address)));
        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user2.address)));
        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user3.address)));
    })

    it("settle and withdraw - rebalance", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await ctk.mint(settlement.address, toWei("175"))
        await settlement.setPoolCash(toWei("50"));
        await settlement.setPerpetualCollateralAmount(0, toWei("125"));

        await settlement.initializeMarginAccount(0, settlement.address, toWei("-500"), toWei("1"));   // pool im = 500 * 1 * 0.1 = 50. send 50 => pool
        await settlement.initializeMarginAccount(0, user1.address, toWei("100"), toWei("0"));   // 100 + nopos
        await settlement.initializeMarginAccount(0, user2.address, toWei("100"), toWei("0.1")); // 100 +  50
        await settlement.initializeMarginAccount(0, user3.address, toWei("0"), toWei("0.2"));   //   0 + 100
        await settlement.registerActiveAccount(0, user1.address);
        await settlement.registerActiveAccount(0, user2.address);
        await settlement.registerActiveAccount(0, user3.address);

        await settlement.setEmergency(0);
        await settlement.clear(0);
        await settlement.clear(0);
        await settlement.clear(0);

        await printSettleState(0);

        expect(await settlement.redemptionRateWithoutPosition(0)).to.equal(toWei("1"));
        expect(await settlement.redemptionRateWithPosition(0)).to.equal(toWei("0.3"));

        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user1.address)));
        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user2.address)));
        console.log(fromWei(await settlement.callStatic.getSettleableMargin(0, user3.address)));

        console.log(fromWei(await ctk.balanceOf(user1.address)));
        await settlement.connect(user1).settle(0, user1.address);
        console.log(fromWei(await ctk.balanceOf(user1.address)));
    })
});