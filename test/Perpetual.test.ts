import BigNumber from 'bignumber.js';
import { expect } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';
import "./helper";


describe('Perpetual', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let oracle;
    let perpetual;
    let ctk;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    beforeEach(async () => {
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        const AMMModule = await createContract("AMMModule");
        const CollateralModule = await createContract("CollateralModule")
        const OrderModule = await createContract("OrderModule");
        const PerpetualModule = await createContract("PerpetualModule");
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
        const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
        perpetual = await createContract("TestPerpetual", [], {
            AMMModule,
            CollateralModule,
            OrderModule,
            PerpetualModule,
            LiquidityPoolModule,
            TradeModule,
        });
        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        await perpetual.createPerpetual(
            oracle.address,
            // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
            [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        )
        await perpetual.setCollateralToken(ctk.address, 1);
        await perpetual.setState(0, 2);
    });

    it("donateInsuranceFund", async () => {
        await ctk.mint(user1.address, toWei("1000"));
        await ctk.connect(user1).approve(perpetual.address, toWei("1000000000000"));

        expect(await perpetual.getTotalCollateral(0)).to.equal(toWei("0"));
        expect(await perpetual.getDonatedInsuranceFund(0)).to.equal(toWei("0"));
        await perpetual.connect(user1).donateInsuranceFund(0, toWei("666"));
        expect(await perpetual.getTotalCollateral(0)).to.equal(toWei("666"));
        expect(await perpetual.getDonatedInsuranceFund(0)).to.equal(toWei("666"));
        expect(await ctk.balanceOf(perpetual.address)).to.equal(toWei("666"));
    })

    it("clear account", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await perpetual.setMarginAccount(0, user1.address, toWei("100"), toWei("0.1")); // 100 + 50
        await perpetual.setMarginAccount(0, user2.address, toWei("200"), toWei("0.2")); // 200 + 100
        await perpetual.setMarginAccount(0, user3.address, toWei("300"), toWei("0.3")); // 300 + 150

        await perpetual.registerActiveAccount(0, user1.address);
        await perpetual.registerActiveAccount(0, user2.address);
        await perpetual.registerActiveAccount(0, user3.address);

        await perpetual.setEmergencyState(0);

        var { left, total } = await perpetual.getClearProgress(0);
        expect(left).to.equal(3);
        expect(total).to.equal(3);

        // await expect(perpetual.clear(0)).to.be.revertedWith("trader is invalid");
        await perpetual.clear(0);
        var { left, total } = await perpetual.getClearProgress(0);
        expect(left).to.equal(2);
        expect(total).to.equal(3);

        await perpetual.clear(0);
        var { left, total } = await perpetual.getClearProgress(0);
        expect(left).to.equal(1);
        expect(total).to.equal(3);

        await perpetual.clear(0);
        var { left, total } = await perpetual.getClearProgress(0);
        expect(left).to.equal(0);
        expect(total).to.equal(3);

        await expect(perpetual.clear(0)).to.be.revertedWith("operation is disallowed now");
    })

    it("settle and withdraw", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await perpetual.setTotalCollateral(0, toWei("175"));

        await perpetual.setMarginAccount(0, user1.address, toWei("100"), toWei("0"));   // 100 + nopos
        await perpetual.setMarginAccount(0, user2.address, toWei("100"), toWei("0.1")); // 100 +  50
        await perpetual.setMarginAccount(0, user3.address, toWei("0"), toWei("0.2"));   //   0 + 100
        await perpetual.registerActiveAccount(0, user1.address);
        await perpetual.registerActiveAccount(0, user2.address);
        await perpetual.registerActiveAccount(0, user3.address);

        await perpetual.setEmergencyState(0);
        await perpetual.clear(0);
        await perpetual.clear(0);
        await perpetual.clear(0);

        expect(await perpetual.redemptionRateWithoutPosition(0)).to.equal(toWei("1"));
        expect(await perpetual.redemptionRateWithPosition(0)).to.equal(toWei("0.3"));

        expect(await perpetual.callStatic.getSettleableMargin(0, user1.address)).to.equal(toWei("100"));
        expect(await perpetual.callStatic.getSettleableMargin(0, user2.address)).to.equal(toWei("45"));
        expect(await perpetual.callStatic.getSettleableMargin(0, user3.address)).to.equal(toWei("30"));
    })

    it("settle and withdraw - rebalance", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await ctk.mint(perpetual.address, toWei("175"))
        await perpetual.setPoolCash(toWei("50"));
        await perpetual.setTotalCollateral(0, toWei("125"));

        await perpetual.setMarginAccount(0, perpetual.address, toWei("-500"), toWei("1"));   // pool im = 500 * 1 * 0.1 = 50. send 50 => pool
        await perpetual.setMarginAccount(0, user1.address, toWei("100"), toWei("0"));   // 100 + nopos
        await perpetual.setMarginAccount(0, user2.address, toWei("100"), toWei("0.1")); // 100 +  50
        await perpetual.setMarginAccount(0, user3.address, toWei("0"), toWei("0.2"));   //   0 + 100
        await perpetual.registerActiveAccount(0, user1.address);
        await perpetual.registerActiveAccount(0, user2.address);
        await perpetual.registerActiveAccount(0, user3.address);

        await perpetual.setEmergencyState(0);
        await perpetual.clear(0);
        await perpetual.clear(0);
        await perpetual.clear(0);

        expect(await perpetual.redemptionRateWithoutPosition(0)).to.equal(toWei("1"));
        expect(await perpetual.redemptionRateWithPosition(0)).to.equal(toWei("0.3"));

        expect(await perpetual.callStatic.getSettleableMargin(0, user1.address)).to.equal(toWei("100"));
        expect(await perpetual.callStatic.getSettleableMargin(0, user2.address)).to.equal(toWei("45"));
        expect(await perpetual.callStatic.getSettleableMargin(0, user3.address)).to.equal(toWei("30"));

        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("0"));
        await perpetual.connect(user1).settle(0, user1.address);
        expect(await ctk.balanceOf(user1.address)).to.equal(toWei("100"));
    })
})

