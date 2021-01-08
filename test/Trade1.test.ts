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

describe('TradeModule1', () => {
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

        let testTrade;
        let ctk;
        let oracle;

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
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], {
                PerpetualModule,
                CollateralModule,
                LiquidityPoolModule,
                TradeModule,
            });
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.2")],
            )
            await testTrade.setOperator(user1.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))
            await testTrade.setCollateralToken(ctk.address, 18);
            await ctk.mint(testTrade.address, toWei("10000000000"));
        })

        it('getFees - 1', async () => {
            // lp = 0.0007, op = 0.0001, vault = 0.0002
            await testTrade.setMarginAccount(0, user0.address, toWei("1000"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0.02"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.04"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.04"));
            expect(operatorFee).to.equal(toWei("0"));
            expect(vaultFee).to.equal(toWei("0"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.07"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0"));
            expect(vaultFee).to.equal(toWei("0"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.08"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.09"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0.01"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.10"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0.02"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.11"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0.02"));
        })

        it('getFees - 2', async () => {
            // lp = 0.0007, op = 0.0001, vault = 0.0002
            await testTrade.setBaseParameter(0, toBytes32("lpFeeRate"), toWei("0"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.02"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0.01"));

            await testTrade.setBaseParameter(0, toBytes32("lpFeeRate"), toWei("0.0007"));
            await testTrade.setBaseParameter(0, toBytes32("operatorFeeRate"), toWei("0"));

            await testTrade.setMarginAccount(0, user0.address, toWei("0.08"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0"));
            expect(vaultFee).to.equal(toWei("0.01"));

            await testTrade.setBaseParameter(0, toBytes32("operatorFeeRate"), toWei("0.0001"));
            await testTrade.setVault(user4.address, toWei("0"))

            await testTrade.setMarginAccount(0, user0.address, toWei("0.08"), toWei("0"));
            var { lpFee, operatorFee, vaultFee } = await testTrade.getFees(0, user0.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(operatorFee).to.equal(toWei("0.01"));
            expect(vaultFee).to.equal(toWei("0"));
        })


        it('updateFees', async () => {
            // lp = 0.0007, op = 0.0001, vault = 0.0002
            await ctk.mint(testTrade.address, toWei("1000"));
            await testTrade.setTotalCollateral(0, toWei("1000"));
            await testTrade.setMarginAccount(0, user0.address, toWei("1000"), toWei("0"));

            var { lpFee, totalFee } = await testTrade.callStatic.updateFees(0, user0.address, none, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(totalFee).to.equal(toWei("0.1"));
            await testTrade.updateFees(0, user0.address, none, toWei("100"));
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("0.01")); // op
            expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0.02")); // vaul12

            // set referrer fee but no referrer
            await testTrade.setBaseParameter(0, toBytes32("referralRebateRate"), toWei("0.5"));
            var { lpFee, totalFee } = await testTrade.callStatic.updateFees(0, user0.address, none, toWei("100"));
            expect(lpFee).to.equal(toWei("0.07"));
            expect(totalFee).to.equal(toWei("0.1"));
            await testTrade.updateFees(0, user0.address, none, toWei("100"));
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("0.02")); // op
            expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0.04")); // vaul12

            // set referrer fee but no referrer
            await testTrade.setBaseParameter(0, toBytes32("referralRebateRate"), toWei("0.5"));
            var { lpFee, totalFee } = await testTrade.callStatic.updateFees(0, user0.address, user2.address, toWei("100"));
            expect(lpFee).to.equal(toWei("0.035"));
            expect(totalFee).to.equal(toWei("0.1"));
            await testTrade.updateFees(0, user0.address, user2.address, toWei("100"));
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("0.025")); // op
            expect(await ctk.balanceOf(user2.address)).to.equal(toWei("0.04")); // op
            expect(await ctk.balanceOf(user4.address)).to.equal(toWei("0.06")); // vaul12
        })

        it('validatePrice', async () => {
            await testTrade.validatePrice(true, toWei("100"), toWei("100"));
            await testTrade.validatePrice(true, toWei("90"), toWei("100"));
            await testTrade.validatePrice(false, toWei("110"), toWei("100"));

            await expect(testTrade.validatePrice(true, toWei("-1"), toWei("100"))).to.be.revertedWith("negative price")
            await expect(testTrade.validatePrice(true, toWei("100.1"), toWei("100"))).to.be.revertedWith("price exceeds limit");
            await expect(testTrade.validatePrice(false, toWei("99.9"), toWei("100"))).to.be.revertedWith("price exceeds limit");
        })

        describe("trade", async () => {
            let user0;
            let user1;
            let user2;
            let user3;
            let user4;
            let user5;
            let testTrade;
            let oracle;

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
                const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
                const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
                testTrade = await createContract("TestTrade", [], {
                    PerpetualModule,
                    CollateralModule,
                    LiquidityPoolModule,
                    TradeModule,
                });
                await testTrade.createPerpetual(
                    oracle.address,
                    // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                    [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0008"), toWei("0"), toWei("0.005"), toWei("2"), toWei("0.0001"), toWei("10000")],
                    [toWei("0.001"), toWei("0.014285714285714285"), toWei("0.012857142857142857"), toWei("0.005"), toWei("5"), toWei("0.05")],
                )
                await testTrade.setOperator(user3.address)
                await testTrade.setVault(user4.address, toWei("0.0001"))
                await testTrade.setCollateralToken(ctk.address, 18);
                await testTrade.setState(0, 2);
                await testTrade.setUnitAccumulativeFunding(0, toWei("9.9059375"))
                await testTrade.setTotalCollateral(0, toWei("10000000000"));
                await ctk.mint(testTrade.address, toWei("10000000000"));
            })

            const testCases = [
                {
                    name: "sell",
                    marginAccount: {
                        cash: toWei('7698.86'),
                        position: toWei('2.3'),
                    },
                    input: {
                        amount: toWei("-0.5"),
                        limitPrice: toWei("0"),
                    },
                    expectOutput: {
                        cash: toWei("11178.8766232"),
                        operatorFee: toWei("0.348845805"),
                    }
                },
                {
                    name: "buy without cross 0",
                    marginAccount: {
                        cash: toWei('7698.86'),
                        position: toWei('2.3'),
                    },
                    input: {
                        amount: toWei("0.5"),
                        limitPrice: toWei("99999999999999"),
                    },
                    expectOutput: {
                        cash: toWei("4204.068831565497225683"),
                        operatorFee: toWei("0.349624788929520756"),
                    }
                },
                {
                    name: "buy cross 0",
                    marginAccount: {
                        cash: toWei('7698.86'),
                        position: toWei('2.3'),
                    },
                    input: {
                        amount: toWei("3.3"),
                        limitPrice: toWei("99999999999999"),
                    },
                    expectOutput: {
                        cash: toWei("-15378.373986752065535528"),
                        operatorFee: toWei("2.308683674375830722"),
                    }
                },
            ]

            testCases.forEach((testCase) => {
                it(testCase.name, async () => {
                    let now = Math.floor(Date.now() / 1000);
                    await oracle.setMarkPrice(toWei("6965"), now);
                    await oracle.setIndexPrice(toWei("7000"), now);
                    await testTrade.updatePrice(now);

                    await testTrade.setMarginAccount(0, user1.address, testCase.marginAccount.cash, testCase.marginAccount.position);
                    await testTrade.setMarginAccount(0, testTrade.address, toWei('83941.29865625'), toWei('2.3'));

                    await testTrade.connect(user1).trade(0, user1.address, testCase.input.amount, testCase.input.limitPrice, user5.address, 0);
                    var { cash } = await testTrade.callStatic.getMarginAccount(0, user1.address);
                    expect(cash).approximateBigNumber(testCase.expectOutput.cash);
                    expect(await testTrade.getClaimableFee(user3.address)).approximateBigNumber(testCase.expectOutput.operatorFee);
                })
            })
        })
    })
})
