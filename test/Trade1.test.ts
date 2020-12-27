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
            const OrderModule = await createContract("OrderModule");
            const PerpetualModule = await createContract("PerpetualModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], {
                AMMModule,
                CollateralModule,
                OrderModule,
                PerpetualModule,
                LiquidityPoolModule,
                TradeModule,
            });
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            )
            await testTrade.setOperator(user0.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))
        })

        it('updateFees', async () => {
            await testTrade.setTotalCollateral(0, toWei("10000"));

            await testTrade.updateFees(0, toWei("10000"), none);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("2"));
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("1"));

            await testTrade.setPerpetualBaseParameter(0, toBytes32("referrerRebateRate"), toWei("0.5"));
            await testTrade.updateFees(0, toWei("10000"), none);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("4")); // 2+2
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("2")); // 1+1
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("0"));

            await testTrade.updateFees(0, toWei("10000"), user1.address);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("6")); // 2+2+2
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("2.5")); // 1+1+0.5
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("4"));
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

                oracle = await createContract("OracleWrapper", ["ctk", "ctk"]);
                const AMMModule = await createContract("AMMModule");
                const CollateralModule = await createContract("CollateralModule")
                const OrderModule = await createContract("OrderModule");
                const PerpetualModule = await createContract("PerpetualModule");
                const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
                const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
                testTrade = await createContract("TestTrade", [], {
                    AMMModule,
                    CollateralModule,
                    OrderModule,
                    PerpetualModule,
                    LiquidityPoolModule,
                    TradeModule,
                });
                await testTrade.createPerpetual(
                    oracle.address,
                    // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                    [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                    [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
                )
                await testTrade.setOperator(user0.address)
                await testTrade.setVault(user4.address, toWei("0.0002"))
            })

            const testCases = [
                {
                    name: "sell",
                    getMarginAccount: {
                        cash: toWei('7698.86'), // 10000 - 2300.23
                        position: toWei('2.3'),
                    },
                    input: {
                        amount: toWei("-0.5"),
                        limitPrice: toWei("0"),
                    },
                    expectOutput: {
                        cash: toWei("11178.003372325"),
                        vaultFee: toWei("0.697516785"),
                        operatorFee: toWei("0.3487583925"),
                    }
                },
                // {
                //     name: "sell - close mm unsafe",
                //     getMarginAccount: {
                //         cash: toWei('-15443'),   // 16070.23 . mm == 626.85
                //         position: toWei('2.3'),
                //         entryFunding: toWei('-0.91'),
                //     },
                //     input: {
                //         amount: toWei("-0.5"),
                //         limitPrice: toWei("0"),
                //     },
                //     expectOutput: {
                //         cash: toWei("-12200.751349815645198533"),
                //         ammCashBalance: toWei("4451.395359950153748472"),
                //     }
                // },
                // {
                //     name: "sell - margin unsafe",
                //     getMarginAccount: {
                //         cash: toWei('-15761'),   // 16070.23 . mm == 626.85
                //         position: toWei('2.3'),
                //         entryFunding: toWei('-0.91'),
                //     },
                //     input: {
                //         amount: toWei("-0.5"),
                //         limitPrice: toWei("0"),
                //     },
                //     expectError: "trader margin is unsafe"
                // },
                {
                    name: "buy without cross 0",
                    getMarginAccount: {
                        cash: toWei('7698.86'),
                        position: toWei('2.3'),
                        entryFunding: toWei('-0.91'),
                    },
                    input: {
                        amount: toWei("0.5"),
                        limitPrice: toWei("99999999999999"),
                    },
                    expectOutput: {
                        cash: toWei("4203.279770389899701152"),
                        vaultFee: toWei("0.699407232439580479"),
                        operatorFee: toWei("0.349703616219790239"),
                    }
                },
                // {
                //     name: "buy - open im unsafe",
                //     getMarginAccount: {
                //         cash: toWei('-14121'),
                //         position: toWei('2.3'),
                //         entryFunding: toWei('-0.91'),
                //     },
                //     input: {
                //         amount: toWei("0.5"),
                //         limitPrice: toWei("99999999999999"),
                //     },
                //     expectError: "trader initial margin is unsafe",
                // },
                {
                    name: "buy cross 0",
                    getMarginAccount: {
                        cash: toWei('7698.86'),
                        position: toWei('2.3'),
                        entryFunding: toWei('-0.91'),
                    },
                    input: {
                        amount: toWei("3.3"),
                        limitPrice: toWei("99999999999999"),
                    },
                    expectOutput: {
                        cash: toWei("-15401.483910332567601064"),
                        vaultFee: toWei("4.621984716100413107"),
                        operatorFee: toWei("2.310992358050206553"),
                    }
                },
            ]

            testCases.forEach((testCase) => {
                it(testCase.name, async () => {
                    await testTrade.setUnitAccumulativeFunding(0, toWei("9.9059375"))

                    let now = Math.floor(Date.now() / 1000);
                    await oracle.setMarkPrice(toWei("6965"), now);
                    await oracle.setIndexPrice(toWei("7000"), now);

                    await testTrade.setMarginAccount(0, testTrade.address, toWei('83941.29865625'), toWei('2.3'));
                    await testTrade.setMarginAccount(0, user1.address, testCase.getMarginAccount.cash, testCase.getMarginAccount.position);
                    if (typeof testCase.expectOutput != "undefined") {
                        await testTrade.trade2(0, user1.address, testCase.input.amount, testCase.input.limitPrice, user5.address, false);
                        var { cash } = await testTrade.getMarginAccount(0, user1.address);
                        expect(cash).approximateBigNumber(testCase.expectOutput.cash);
                        expect(await testTrade.getClaimableFee(user4.address)).approximateBigNumber(testCase.expectOutput.vaultFee);
                        expect(await testTrade.getClaimableFee(user3.address)).approximateBigNumber(testCase.expectOutput.operatorFee);
                    } else {
                        await expect(testTrade.trade2(0, user1.address, testCase.input.amount, testCase.input.limitPrice, user5.address, false))
                            .to.be.revertedWith(testCase["expectError"])
                    }
                })
            })
        })
    })
})