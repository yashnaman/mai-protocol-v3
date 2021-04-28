import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    fromBytes32,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

import "./helper";

describe('TradeModule4 - auto deposit/withdraw with targetLeverage', () => {
    let accounts;

    before(async () => {
        accounts = await getAccounts();
    })

    describe('basic', async () => {
        let user0;
        let user1;
        let user2;
        let user3;
        let user4;
        let user5;
        let none = "0x0000000000000000000000000000000000000000";
        let USE_TARGET_LEVERAGE = 0x08000000;

        let testTrade;
        let ctk;
        let oracle;
        let mocker;

        beforeEach(async () => {
            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];

            ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            oracle = await createContract("OracleWrapper", ["ctk", "ctk"]);
            const AMMModule = await createContract("AMMModule");
            const CollateralModule = await createContract("CollateralModule")
            const PerpetualModule = await createContract("PerpetualModule");
            const OrderModule = await createContract("OrderModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });

            const MockAMMModule = await createContract("MockAMMModule");
            const TradeModule = await createContract("TradeModule", [], { AMMModule: MockAMMModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], {
                PerpetualModule,
                CollateralModule,
                LiquidityPoolModule,
                OrderModule,
                TradeModule,
            });
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr       lpfr             rebate      penalty         keeper      insur       oi
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0"), toWei("5"), toWei("0.2"), toWei("0.01"), toWei("1")],
            )
            await testTrade.setOperator(user0.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))
            await testTrade.setCollateralToken(ctk.address, 18);
            await ctk.mint(testTrade.address, toWei("10000000000"));

            mocker = await createContract("MockAMMPriceEntries");
            await testTrade.setGovernor(mocker.address);
            await testTrade.setState(0, 2);
        })

        it("regular - 1x", async () => {
            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(toWei("1000"), now);
            await oracle.setIndexPrice(toWei("1000"), now);
            await testTrade.updatePrice(now);

            await mocker.setPrice(toWei("1000"));

            await ctk.mint(user1.address, toWei("10000"));
            await ctk.connect(user1).approve(testTrade.address, toWei("10000"))

            await ctk.mint(testTrade.address, toWei("1000"));
            await testTrade.setTotalCollateral(0, toWei("1000"));

            await testTrade.setTargetLeverage(0, user1.address, toWei("1")); // 1x target leverage
            await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

            await testTrade.connect(user1).trade(0, user1.address, toWei("1"), toWei("20000"), none, USE_TARGET_LEVERAGE);
            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).approximateBigNumber(toWei("0"))
            expect(position).to.equal(toWei("1"))
            expect(await ctk.balanceOf(user1.address)).approximateBigNumber(toWei("8999"))
        })

        it("close", async () => {
            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(toWei("1000"), now);
            await oracle.setIndexPrice(toWei("1000"), now);
            await testTrade.updatePrice(now);
            await mocker.setPrice(toWei("1000"));

            await ctk.mint(testTrade.address, toWei("100000"));
            await testTrade.setTotalCollateral(0, toWei("100000"));

            await testTrade.setMarginAccount(0, user1.address, toWei("10000"), toWei("10")); // 10000 + 10 * 1000 / 10000 = 2:1
            await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

            // close only
            await expect(testTrade.connect(user1).trade(0, user1.address, toWei("1"), toWei("20000"), none, 0x80000000)).to.be.revertedWith("trader must be close only");
            await testTrade.connect(user1).trade(0, user1.address, toWei("-1"), toWei("0"), none, 0x88000000);
            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).to.equal(toWei("9000"))  // 9000 + 9 * 1000 : 9000
            expect(position).to.equal(toWei("9"))
            expect(await ctk.balanceOf(user1.address)).to.equal(toWei("1999"))

            var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
            expect(position).to.equal(toWei("1"))
            expect(cash).to.equal(toWei("-900")) // 9000 rebalance 9900 => pool
            expect(await testTrade.getPoolCash()).to.equal(toWei("9900.7")) // 0.7 + 9900 
        })

        //     it("close - but no fee", async () => {
        //         let now = Math.floor(Date.now() / 1000);
        //         await oracle.setMarkPrice(toWei("1000"), now);
        //         await oracle.setIndexPrice(toWei("1000"), now);
        //         await testTrade.updatePrice(now);

        //         await mocker.setPrice(toWei("1000"));
        //         await ctk.mint(testTrade.address, toWei("1000"));
        //         await testTrade.setTotalCollateral(0, toWei("1000"));

        //         // close only + half fee
        //         await testTrade.setMarginAccount(0, user1.address, toWei("-9099.5"), toWei("10")); // margin = 9000 900
        //         await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

        //         await testTrade.connect(user1).trade(0, user1.address, toWei("-1"), toWei("0"), none, 0x80000000);
        //         var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
        //         expect(cash).to.equal(toWei("-8100")) // 1000 + fee = 0.001 //
        //         expect(position).to.equal(toWei("9"))
        //         var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
        //         expect(cash).to.equal(toWei("9000")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("1"))

        //         // close only + no fee
        //         await testTrade.setMarginAccount(0, user1.address, toWei("-9100"), toWei("10")); // margin = 9000 900
        //         await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

        //         await testTrade.connect(user1).trade(0, user1.address, toWei("-1"), toWei("0"), none, 0x80000000);
        //         var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
        //         expect(cash).to.equal(toWei("-8100")) // 1000 + fee = 0.001 //
        //         expect(position).to.equal(toWei("9"))
        //         expect(await testTrade.getMargin(0, user1.address)).to.equal(toWei("900")) // im safe
        //         var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
        //         expect(cash).to.equal(toWei("9000")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("1"))

        //         // close only + no margin
        //         await testTrade.setMarginAccount(0, user1.address, toWei("-9999"), toWei("10")); // margin = 9000 900
        //         await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

        //         await testTrade.connect(user1).trade(0, user1.address, toWei("-1"), toWei("0"), none, 0x80000000);
        //         var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
        //         expect(cash).to.equal(toWei("-8999")) // 1000 + fee = 0.001 //
        //         expect(position).to.equal(toWei("9"))
        //         expect(await testTrade.getMargin(0, user1.address)).to.equal(toWei("1")) // im unsafe/margin safe
        //         var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
        //         expect(cash).to.equal(toWei("9000")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("1"))

        //         // no margin + close all
        //         await testTrade.setMarginAccount(0, user1.address, toWei("-10000"), toWei("10")); // margin = 9000 900
        //         await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

        //         await testTrade.connect(user1).trade(0, user1.address, toWei("-10"), toWei("0"), none, 0x80000000);
        //         var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
        //         expect(cash).to.equal(toWei("0")) // 1000 + fee = 0.001 //
        //         expect(position).to.equal(toWei("0"))
        //         expect(await testTrade.getMargin(0, user1.address)).to.equal("0") // im unsafe/margin safe
        //         var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
        //         expect(cash).to.equal(toWei("0")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("10"))
        //     })

        //     it("market", async () => {
        //         let now = Math.floor(Date.now() / 1000);
        //         await oracle.setMarkPrice(toWei("1000"), now);
        //         await oracle.setIndexPrice(toWei("1000"), now);
        //         await testTrade.updatePrice(now);

        //         await mocker.setPrice(toWei("1000"));
        //         await ctk.mint(testTrade.address, toWei("1000"));
        //         await testTrade.setTotalCollateral(0, toWei("1000"));

        //         await testTrade.setMarginAccount(0, user1.address, toWei("10000"), toWei("10"));
        //         await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

        //         await expect(testTrade.connect(user1).trade(0, user1.address, toWei("1"), toWei("0"), none, 0)).to.be.revertedWith("price exceeds limit");

        //         await testTrade.connect(user1).trade(0, user1.address, toWei("1"), toWei("0"), none, 0x40000000);
        //         var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
        //         expect(cash).to.equal(toWei("8999")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("11"))
        //         var { cash, position } = await testTrade.getMarginAccount(0, testTrade.address);
        //         expect(cash).to.equal(toWei("11000")) // 1000 + fee = 0.001
        //         expect(position).to.equal(toWei("-1"))
        //     })
    })
})