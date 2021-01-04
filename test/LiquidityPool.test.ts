import BigNumber from 'bignumber.js';
import { expect, use } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';
import "./helper";


describe('LiquidityPool', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let liquidityPool;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    beforeEach(async () => {
        const CollateralModule = await createContract("CollateralModule")
        const SignatureModule = await createContract("OrderModule");
        const PerpetualModule = await createContract("PerpetualModule");
        const AMMModule = await createContract("AMMModule");
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], {
            AMMModule,
            CollateralModule,
            PerpetualModule,
            SignatureModule,
        });
        liquidityPool = await createContract("TestLiquidityPool", [], {
            LiquidityPoolModule,
            PerpetualModule
        });
    });

    describe("2 liquidityPool group", async () => {
        let oracle0;
        let oracle1;

        beforeEach(async () => {
            oracle0 = await createContract("OracleWrapper", ["USD", "ETH"]);
            oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
            await liquidityPool.createPerpetual(
                oracle0.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            )
            await liquidityPool.createPerpetual(
                oracle1.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.2"), toWei("0.1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            )
            await liquidityPool.setState(0, 2);
            await liquidityPool.setState(1, 2);
        })

        // it("updatePrice", async () => {
        //     var now = 1000;
        //     await oracle0.setMarkPrice(toWei("100"), now);
        //     await oracle0.setIndexPrice(toWei("101"), now);
        //     await oracle1.setMarkPrice(toWei("200"), now);
        //     await oracle1.setIndexPrice(toWei("201"), now);

        //     expect(await liquidityPool.getPriceUpdateTime()).to.equal(0);
        //     await liquidityPool.updatePrice(1000);
        //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("100"));
        //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("101"));
        //     expect(await liquidityPool.getMarkPrice(1)).to.equal(toWei("200"));
        //     expect(await liquidityPool.getIndexPrice(1)).to.equal(toWei("201"));
        //     expect(await liquidityPool.getPriceUpdateTime()).to.equal(1000);

        //     now = 2000;
        //     await oracle0.setMarkPrice(toWei("100.1"), now);
        //     await oracle0.setIndexPrice(toWei("101.1"), now);
        //     await oracle1.setMarkPrice(toWei("200.1"), now);
        //     await oracle1.setIndexPrice(toWei("201.1"), now);

        //     await liquidityPool.updatePrice(1000);
        //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("100"));
        //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("101"));
        //     expect(await liquidityPool.getMarkPrice(1)).to.equal(toWei("200"));
        //     expect(await liquidityPool.getIndexPrice(1)).to.equal(toWei("201"));
        //     expect(await liquidityPool.getPriceUpdateTime()).to.equal(1000);

        //     await liquidityPool.updatePrice(2000);
        //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("100.1"));
        //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("101.1"));
        //     expect(await liquidityPool.getMarkPrice(1)).to.equal(toWei("200.1"));
        //     expect(await liquidityPool.getIndexPrice(1)).to.equal(toWei("201.1"));
        //     expect(await liquidityPool.getPriceUpdateTime()).to.equal(2000);
        // })

        // it("getAvailablePoolCash", async () => {
        //     var now = 1000;
        //     await oracle0.setMarkPrice(toWei("100"), now);
        //     await oracle0.setIndexPrice(toWei("100"), now);
        //     await oracle1.setMarkPrice(toWei("200"), now);
        //     await oracle1.setIndexPrice(toWei("200"), now);
        //     await liquidityPool.updatePrice(1000);

        //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("100"), toWei("1"));
        //     await liquidityPool.setMarginAccount(1, liquidityPool.address, toWei("50"), toWei("-1"));
        //     await liquidityPool.setPoolCash(toWei("10"));
        //     // all = 10 + [100 + (1*100 - 1*100*0.1)] + [50 + (-1*200 - |-1*200|*0.2)]
        //     //     = 10 + 190 - 190
        //     expect(await liquidityPool.getAvailablePoolCash(0)).to.equal(toWei("-180"));
        //     expect(await liquidityPool.getAvailablePoolCash(2)).to.equal(toWei("10"));

        //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("100"), toWei("1"));
        //     await liquidityPool.setMarginAccount(1, liquidityPool.address, toWei("50"), toWei("-1"));
        //     await liquidityPool.setPoolCash(toWei("-100"));
        //     // all = 10 + [100 + (1*100 - 1*100*0.1)] + [50 + (-1*200 - |-1*200|*0.2)]
        //     //     = 10 + 190 - 190
        //     expect(await liquidityPool.getAvailablePoolCash(0)).to.equal(toWei("-290"));
        //     expect(await liquidityPool.getAvailablePoolCash(2)).to.equal(toWei("-100"));
        // })

        it("", async () => {

        })
    })

    // it("getMarkPrice && getIndexPrice", async () => {
    //     var now = Math.floor(Date.now() / 1000);
    //     await oracle.setMarkPrice(toWei("500"), now);
    //     await oracle.setIndexPrice(toWei("501"), now);

    //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("0"));

    //     var tx = await liquidityPool.updatePrice(0);
    //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("500"));
    //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("501"));

    //     await liquidityPool.updatePrice(0);
    //     await liquidityPool.setEmergencyState(0);

    //     await oracle.setMarkPrice(toWei("600"), now);
    //     await oracle.setIndexPrice(toWei("601"), now);
    //     expect(await liquidityPool.getMarkPrice(0)).to.equal(toWei("500"));
    //     expect(await liquidityPool.getIndexPrice(0)).to.equal(toWei("500"));
    // });

    // it("getRebalanceMargin", async () => {
    //     var now = Math.floor(Date.now() / 1000);
    //     await oracle.setMarkPrice(toWei("500"), now);
    //     await oracle.setIndexPrice(toWei("500"), now);
    //     await liquidityPool.updatePrice(0);

    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("0"), toWei("1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("450"));
    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("-500"), toWei("1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("-50"));
    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("-450"), toWei("1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("0"));

    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("0"), toWei("0"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("0"));

    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("500"), toWei("-1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("-50"));
    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("-500"), toWei("-1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("-1050"));
    //     await liquidityPool.setMarginAccount(0, liquidityPool.address, toWei("550"), toWei("-1"));
    //     expect(await liquidityPool.getRebalanceMargin(0)).to.equal(toWei("0"));

    // });

    // it("setNormalState", async () => {
    //     await liquidityPool.setState(0, 1);
    //     expect(await liquidityPool.getState(0)).to.equal(1);

    //     await liquidityPool.setNormalState(0);
    //     expect(await liquidityPool.getState(0)).to.equal(2);

    //     await liquidityPool.setState(0, 0);
    //     await expect(liquidityPool.setNormalState(0)).to.be.revertedWith("liquidityPool should be in initializing state");
    //     await liquidityPool.setState(0, 2);
    //     await expect(liquidityPool.setNormalState(0)).to.be.revertedWith("liquidityPool should be in initializing state");
    //     await liquidityPool.setState(0, 3);
    //     await expect(liquidityPool.setNormalState(0)).to.be.revertedWith("liquidityPool should be in initializing state");
    //     await liquidityPool.setState(0, 4);
    //     await expect(liquidityPool.setNormalState(0)).to.be.revertedWith("liquidityPool should be in initializing state");
    // });

    // it("setEmergencyState", async () => {
    //     await liquidityPool.setState(0, 2);
    //     expect(await liquidityPool.getState(0)).to.equal(2);

    //     await liquidityPool.setEmergencyState(0);
    //     expect(await liquidityPool.getState(0)).to.equal(3);

    //     await liquidityPool.setState(0, 0);
    //     await expect(liquidityPool.setEmergencyState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 1);
    //     await expect(liquidityPool.setEmergencyState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 3);
    //     await expect(liquidityPool.setEmergencyState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 4);
    //     await expect(liquidityPool.setEmergencyState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    // });

    // it("setClearedState", async () => {
    //     await liquidityPool.setState(0, 3);
    //     expect(await liquidityPool.getState(0)).to.equal(3);

    //     await liquidityPool.setClearedState(0);
    //     expect(await liquidityPool.getState(0)).to.equal(4);

    //     await liquidityPool.setState(0, 0);
    //     await expect(liquidityPool.setClearedState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 1);
    //     await expect(liquidityPool.setClearedState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 2);
    //     await expect(liquidityPool.setClearedState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    //     await liquidityPool.setState(0, 4);
    //     await expect(liquidityPool.setClearedState(0)).to.be.revertedWith("liquidityPool should be in normal state");
    // })


    // it("donateInsuranceFund", async () => {
    //     await liquidityPool.setState(0, 2);

    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("0"));
    //     await liquidityPool.donateInsuranceFund(0, toWei("10"));
    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("10"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("10"));

    //     await liquidityPool.donateInsuranceFund(0, toWei("11"));
    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("21"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("21"));

    //     await expect(liquidityPool.donateInsuranceFund(0, toWei("0"))).to.be.revertedWith("amount should greater than 0");
    //     await expect(liquidityPool.donateInsuranceFund(0, toWei("-1"))).to.be.revertedWith("amount should greater than 0");
    // })


    // it("deposit", async () => {
    //     await liquidityPool.setState(0, 2);

    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.isTraderRegistered(0, user0.address)).to.be.false;

    //     await liquidityPool.deposit(0, user0.address, toWei("10"));
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("10"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.isTraderRegistered(0, user0.address)).to.be.true;

    //     await liquidityPool.deposit(0, user0.address, toWei("11"));
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("21"));
    //     expect(position).to.equal(toWei("0"));

    //     await expect(liquidityPool.deposit(0, user0.address, toWei("0"))).to.be.revertedWith("amount should greater than 0");
    //     await expect(liquidityPool.deposit(0, user0.address, toWei("-1"))).to.be.revertedWith("amount should greater than 0");
    // })

    // it("withdraw", async () => {
    //     await liquidityPool.setState(0, 2);

    //     await liquidityPool.deposit(0, user0.address, toWei("100"));
    //     expect(await liquidityPool.isTraderRegistered(0, user0.address)).to.be.true;

    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("100"));
    //     expect(position).to.equal(toWei("0"));

    //     await liquidityPool.withdraw(0, user0.address, toWei("10"));
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("90"));
    //     expect(position).to.equal(toWei("0"));

    //     await liquidityPool.withdraw(0, user0.address, toWei("90"));
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.isTraderRegistered(0, user0.address)).to.be.false;

    //     await expect(liquidityPool.withdraw(0, user0.address, toWei("0"))).to.be.revertedWith("amount should greater than 0");
    //     await expect(liquidityPool.withdraw(0, user0.address, toWei("-1"))).to.be.revertedWith("amount should greater than 0");
    // })

    // it("clear", async () => {
    //     await liquidityPool.setState(0, 2);

    //     await liquidityPool.deposit(0, user0.address, toWei("1"));
    //     await liquidityPool.deposit(0, user1.address, toWei("2"));
    //     await liquidityPool.deposit(0, user2.address, toWei("3"));
    //     await liquidityPool.deposit(0, user3.address, toWei("4"));
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(4);

    //     await liquidityPool.setEmergencyState(0);
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(4);

    //     await liquidityPool.clear(0, user0.address);
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(3);

    //     await liquidityPool.clear(0, user1.address);
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(2);

    //     expect(await liquidityPool.callStatic.clear(0, user2.address)).to.be.false;
    //     await liquidityPool.clear(0, user2.address);
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(1);

    //     await expect(liquidityPool.clear(0, user2.address)).to.be.revertedWith("account cannot be cleared or already cleared");

    //     expect(await liquidityPool.callStatic.clear(0, user3.address)).to.be.true;
    //     await liquidityPool.clear(0, user3.address);
    //     expect(await liquidityPool.getActiveUserCount(0)).to.equal(0);

    //     await expect(liquidityPool.clear(0, user3.address)).to.be.revertedWith("no account to clear");
    // })

    // it("clear - 2", async () => {
    //     await liquidityPool.setState(0, 2);

    //     var now = Math.floor(Date.now() / 1000);
    //     await oracle.setMarkPrice(toWei("100"), now);
    //     await oracle.setIndexPrice(toWei("100"), now);
    //     await liquidityPool.updatePrice(0);

    //     await liquidityPool.registerActiveAccount(0, user0.address);
    //     await liquidityPool.registerActiveAccount(0, user1.address);
    //     await liquidityPool.registerActiveAccount(0, user2.address);
    //     await liquidityPool.registerActiveAccount(0, user3.address);
    //     await liquidityPool.setMarginAccount(0, user0.address, toWei("100"), toWei("0"));
    //     await liquidityPool.setMarginAccount(0, user1.address, toWei("200"), toWei("0"));
    //     await liquidityPool.setMarginAccount(0, user2.address, toWei("-200"), toWei("1"));
    //     await liquidityPool.setMarginAccount(0, user3.address, toWei("0"), toWei("1"));

    //     await liquidityPool.setEmergencyState(0);

    //     await liquidityPool.clear(0, user0.address);
    //     expect(await liquidityPool.getTotalMarginWithPosition(0)).to.equal("0");
    //     expect(await liquidityPool.getTotalMarginWithoutPosition(0)).to.equal(toWei("100"));

    //     await liquidityPool.clear(0, user1.address);
    //     expect(await liquidityPool.getTotalMarginWithPosition(0)).to.equal("0");
    //     expect(await liquidityPool.getTotalMarginWithoutPosition(0)).to.equal(toWei("300"));
    //     await liquidityPool.clear(0, user2.address);
    //     expect(await liquidityPool.getTotalMarginWithPosition(0)).to.equal("0");
    //     expect(await liquidityPool.getTotalMarginWithoutPosition(0)).to.equal(toWei("300"));

    //     await liquidityPool.clear(0, user3.address);
    //     expect(await liquidityPool.getTotalMarginWithPosition(0)).to.equal(toWei("100"));
    //     expect(await liquidityPool.getTotalMarginWithoutPosition(0)).to.equal(toWei("300"));

    //     await liquidityPool.setClearedState(0);

    //     // p = 100, nop = 300
    //     await liquidityPool.setTotalCollateral(0, toWei("300"))
    //     await liquidityPool.settleCollateral(0);
    //     expect(await liquidityPool.getRedemptionRateWithoutPosition(0)).to.equal(toWei("1"));
    //     expect(await liquidityPool.getRedemptionRateWithPosition(0)).to.equal(toWei("0"));

    //     await liquidityPool.setTotalCollateral(0, toWei("350"))
    //     await liquidityPool.settleCollateral(0);
    //     expect(await liquidityPool.getRedemptionRateWithoutPosition(0)).to.equal(toWei("1"));
    //     expect(await liquidityPool.getRedemptionRateWithPosition(0)).to.equal(toWei("0.5"));

    //     await liquidityPool.setTotalCollateral(0, toWei("150"))
    //     await liquidityPool.settleCollateral(0);
    //     expect(await liquidityPool.getRedemptionRateWithoutPosition(0)).to.equal(toWei("0.5"));
    //     expect(await liquidityPool.getRedemptionRateWithPosition(0)).to.equal(toWei("0"));

    //     await liquidityPool.setTotalCollateral(0, toWei("0"))
    //     await liquidityPool.settleCollateral(0);
    //     expect(await liquidityPool.getRedemptionRateWithoutPosition(0)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getRedemptionRateWithPosition(0)).to.equal(toWei("0"));
    // })


    // it("getNextActiveAccount", async () => {
    //     await liquidityPool.setState(0, 2);

    //     await liquidityPool.deposit(0, user0.address, toWei("1"));
    //     await liquidityPool.deposit(0, user1.address, toWei("2"));
    //     await liquidityPool.deposit(0, user2.address, toWei("3"));
    //     await liquidityPool.deposit(0, user3.address, toWei("4"));

    //     var account = await liquidityPool.getNextActiveAccount(0);
    //     expect(account).to.equal(user0.address);
    //     await liquidityPool.clear(0, account);

    //     var account = await liquidityPool.getNextActiveAccount(0);
    //     expect(account).to.equal(user3.address);
    //     await liquidityPool.clear(0, account);

    //     var account = await liquidityPool.getNextActiveAccount(0);
    //     expect(account).to.equal(user2.address);
    //     await liquidityPool.clear(0, account);

    //     var account = await liquidityPool.getNextActiveAccount(0);
    //     expect(account).to.equal(user1.address);
    //     await liquidityPool.clear(0, account);

    //     await expect(liquidityPool.getNextActiveAccount(0)).to.be.revertedWith("no active account");
    // })

    // it("settle", async () => {
    //     await liquidityPool.setState(0, 2);

    //     var now = Math.floor(Date.now() / 1000);
    //     await oracle.setMarkPrice(toWei("100"), now);
    //     await oracle.setIndexPrice(toWei("100"), now);
    //     await liquidityPool.updatePrice(0);

    //     await liquidityPool.registerActiveAccount(0, user0.address);
    //     await liquidityPool.registerActiveAccount(0, user1.address);
    //     await liquidityPool.registerActiveAccount(0, user2.address);
    //     await liquidityPool.registerActiveAccount(0, user3.address);
    //     await liquidityPool.setMarginAccount(0, user0.address, toWei("100"), toWei("0"));
    //     await liquidityPool.setMarginAccount(0, user1.address, toWei("200"), toWei("0"));
    //     await liquidityPool.setMarginAccount(0, user2.address, toWei("-200"), toWei("1"));
    //     await liquidityPool.setMarginAccount(0, user3.address, toWei("0"), toWei("1"));

    //     await liquidityPool.setEmergencyState(0);
    //     await liquidityPool.clear(0, user0.address);
    //     await liquidityPool.clear(0, user1.address);
    //     await liquidityPool.clear(0, user2.address);
    //     await liquidityPool.clear(0, user3.address);

    //     await liquidityPool.setClearedState(0);
    //     // p = 100, nop = 300
    //     await liquidityPool.setTotalCollateral(0, toWei("350"))
    //     await liquidityPool.settleCollateral(0);
    //     expect(await liquidityPool.getRedemptionRateWithoutPosition(0)).to.equal(toWei("1"));
    //     expect(await liquidityPool.getRedemptionRateWithPosition(0)).to.equal(toWei("0.5"));

    //     expect(await liquidityPool.getSettleableMargin(0, user0.address)).to.equal(toWei("100"));
    //     expect(await liquidityPool.getSettleableMargin(0, user1.address)).to.equal(toWei("200"));
    //     expect(await liquidityPool.getSettleableMargin(0, user2.address)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getSettleableMargin(0, user3.address)).to.equal(toWei("50"));

    //     expect(await liquidityPool.callStatic.settle(0, user0.address)).to.equal(toWei("100"));
    //     await liquidityPool.settle(0, user0.address);
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user0.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("250"));

    //     expect(await liquidityPool.callStatic.settle(0, user1.address)).to.equal(toWei("200"));
    //     await liquidityPool.settle(0, user1.address);
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user1.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("50"));

    //     expect(await liquidityPool.callStatic.settle(0, user2.address)).to.equal(toWei("0"));
    //     await liquidityPool.settle(0, user2.address);
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user2.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("50"));

    //     expect(await liquidityPool.callStatic.settle(0, user3.address)).to.equal(toWei("50"));
    //     await liquidityPool.settle(0, user3.address);
    //     var { cash, position } = await liquidityPool.getMarginAccount(0, user3.address);
    //     expect(cash).to.equal(toWei("0"));
    //     expect(position).to.equal(toWei("0"));
    //     expect(await liquidityPool.getTotalCollateral(0)).to.equal(toWei("0"));
    // })


    // it("updateInsuranceFund", async () => {
    //     await liquidityPool.setState(0, 2);

    //     await liquidityPool.setBaseParameter(0, toBytes32("insuranceFundCap"), toWei("100"));

    //     expect(await liquidityPool.getInsuranceFund(0)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("0"));

    //     await liquidityPool.updateInsuranceFund(0, toWei("0"));
    //     expect(await liquidityPool.getInsuranceFund(0)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("0"));

    //     await liquidityPool.updateInsuranceFund(0, toWei("0"));
    //     expect(await liquidityPool.getInsuranceFund(0)).to.equal(toWei("0"));
    //     expect(await liquidityPool.getDonatedInsuranceFund(0)).to.equal(toWei("0"));
    // })
})

