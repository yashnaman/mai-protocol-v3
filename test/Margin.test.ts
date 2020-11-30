const { ethers } = require("hardhat");
import { expect } from "chai";
import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';


describe('MarginModule', () => {
    let accounts;

    before(async () => {
        accounts = await getAccounts();
    })

    describe('Getters', async () => {
        let testMargin;

        beforeEach(async () => {
            const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            const oracle = await createContract("OracleWrapper", [erc20.address]);
            const FundingModule = await createContract("FundingModule");
            const ParameterModule = await createContract("ParameterModule");
            testMargin = await createContract("TestMargin", [oracle.address], { FundingModule, ParameterModule });
        })
        const testCases = [
            {
                name: "+initialMargin",
                method: "initialMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("50")
            },
            {
                name: "-initialMargin",
                method: "initialMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("50")
            },
            {
                name: "+initialMargin - non-zero keeperGasReward",
                method: "initialMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("0.1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                    keeperGasReward: toWei("6"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("6")
            },
            {
                name: "-initialMargin - non-zero keeperGasReward",
                method: "initialMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("-0.1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                    keeperGasReward: toWei("6"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("6")
            },
            {
                name: "+maintenanceMargin",
                method: "maintenanceMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.05"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("25")
            },
            {
                name: "-maintenanceMargin",
                method: "maintenanceMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.05"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("25")
            },
            {
                name: "+margin",
                method: "margin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1")
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("600")
            },
            {
                name: "-margin",
                method: "margin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1")
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("-400")
            },
            {
                name: "+availableMargin",
                method: "availableMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1")
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("550") // 500 + 50
            },
            {
                name: "-availableMargin",
                method: "availableMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("0"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1")
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("-550") // 0 -500 -50
            },
            {
                name: "+positionAmount",
                method: "positionAmount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("1")
            },
            {
                name: "-positionAmount",
                method: "positionAmount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("1")
            },
            {
                name: "availableCashBalance + funding",
                method: "availableCashBalance",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: toWei("90") // 100 - (1*10 - 0)
            },
            {
                name: "availableCashBalance - funding 1",
                method: "availableCashBalance",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("20"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: toWei("110") // 100 - (1*10 - 20)
            },
            {
                name: "availableCashBalance - funding 2",
                method: "availableCashBalance",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("20"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("120") // 100 - (0 - 20)
            },
            {
                name: "+isInitialMarginSafe yes",
                method: "isInitialMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("-450"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: true, // 500 - 450 vs 50
            },
            {
                name: "-isInitialMarginSafe yes",
                method: "isInitialMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("550"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: true, // -500 + 550 vs 50
            },
            {
                name: "+isInitialMarginSafe no",
                method: "isInitialMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("-450.1"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: false, // 500 - 450.1 vs 50
            },
            {
                name: "-isInitialMarginSafe no",
                method: "isInitialMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("549.9"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: false, // -500 + 549.9 vs 50
            },
            {
                name: "+isMaintenanceMarginSafe yes",
                method: "isMaintenanceMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("-450"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: true,
            },
            {
                name: "-isMaintenanceMarginSafe yes",
                method: "isMaintenanceMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("550"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: true,
            },
            {
                name: "+isMaintenanceMarginSafe no",
                method: "isMaintenanceMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("-450.1"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: false,
            },
            {
                name: "-isMaintenanceMarginSafe no",
                method: "isMaintenanceMarginSafe",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("549.9"),
                    positionAmount: toWei("-1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    maintenanceMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: false, // 549.9 -500 >= |-1 * 500 * 0.1|
            },
            {
                method: "isEmptyAccount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("0"),
                    positionAmount: toWei("0"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: true,
            },
            {
                name: "isEmptyAccount - 1",
                method: "isEmptyAccount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("1"),
                    positionAmount: toWei("0"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: false,
            },
            {
                name: "isEmptyAccount - 2",
                method: "isEmptyAccount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("0"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: false,
            },
            {
                name: "isEmptyAccount - 3",
                method: "isEmptyAccount",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("0"),
                    positionAmount: toWei("0"),
                    entryFunding: toWei("1"),
                },
                parameters: {
                    initialMarginRate: toWei("0.1"),
                },
                unitAccumulativeFunding: toWei("10"),
                trader: 0,
                expect: false,
            },
        ]

        testCases.forEach((testCase) => {
            it(testCase["name"] || testCase.method, async () => {
                await testMargin.updateMarkPrice(testCase.markPrice);
                await testMargin.initializeMarginAccount(
                    accounts[testCase.trader].address,
                    testCase.marginAccount.cashBalance,
                    testCase.marginAccount.positionAmount,
                    testCase.marginAccount.entryFunding);
                for (var key in testCase.parameters || {}) {
                    // console.log("set", key, "=>", testCase.parameters[key].toString())
                    await testMargin.updateCoreParameter(toBytes32(key), testCase.parameters[key]);
                }
                await testMargin.updateUnitAccumulativeFunding(testCase.unitAccumulativeFunding);
                if (typeof testCase.expect != "undefined") {
                    const result = await testMargin.callStatic[testCase.method](accounts[testCase.trader].address);
                    expect(result).to.equal(testCase["expect"])
                } else {
                    const result = await testMargin.callStatic[testCase.method](accounts[testCase.trader].address);
                    expect(result).to.be.revertedWith(testCase["expectError"])
                }
            })
        })
    })


    describe('Setters', async () => {
        let testMargin;

        before(async () => {
            const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            const oracle = await createContract("OracleWrapper", [erc20.address]);
            const FundingModule = await createContract("FundingModule");
            const ParameterModule = await createContract("ParameterModule");
            testMargin = await createContract("TestMargin", [oracle.address], { FundingModule, ParameterModule, });
        })

        it("openPosition - 0 => long", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.openPosition(trader, toWei("2"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("2"));
            expect(entryFunding).to.equal(toWei("200"));

            await testMargin.openPosition(trader, toWei("1"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("3"));
            expect(entryFunding).to.equal(toWei("300"));

            await testMargin.updateUnitAccumulativeFunding(toWei("200"));
            await testMargin.openPosition(trader, toWei("1"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("4"));
            expect(entryFunding).to.equal(toWei("500"));
        })

        it("openPosition - 0 => short", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.openPosition(trader, toWei("-2"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("-2"));
            expect(entryFunding).to.equal(toWei("-200"));

            await testMargin.openPosition(trader, toWei("-1"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("-3"));
            expect(entryFunding).to.equal(toWei("-300"));

            await testMargin.updateUnitAccumulativeFunding(toWei("200"));
            await testMargin.openPosition(trader, toWei("-1"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("-4"));
            expect(entryFunding).to.equal(toWei("-500"));
        })

        it("closePosition - long => short", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.openPosition(trader, toWei("2"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("2"));
            expect(entryFunding).to.equal(toWei("200"));

            await testMargin.closePosition(trader, toWei("-0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("1.5"));
            expect(entryFunding).to.equal(toWei("150"));

            await testMargin.updateUnitAccumulativeFunding(toWei("200"));
            await testMargin.closePosition(trader, toWei("-0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("950"));
            expect(positionAmount).to.equal(toWei("1"));
            expect(entryFunding).to.equal(toWei("100"));

            await testMargin.updateUnitAccumulativeFunding(toWei("0"));
            await testMargin.closePosition(trader, toWei("-0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("0.5"));
            expect(entryFunding).to.equal(toWei("50"));

            await testMargin.updateUnitAccumulativeFunding(toWei("-100"));
            await testMargin.closePosition(trader, toWei("-0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1100"));
            expect(positionAmount).to.equal(toWei("0"));
            expect(entryFunding).to.equal(toWei("0"));
        })

        it("closePosition - short => long", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.openPosition(trader, toWei("-2"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("-2"));
            expect(entryFunding).to.equal(toWei("-200"));

            await testMargin.closePosition(trader, toWei("0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000"));
            expect(positionAmount).to.equal(toWei("-1.5"));
            expect(entryFunding).to.equal(toWei("-150"));

            await testMargin.updateUnitAccumulativeFunding(toWei("200"));
            await testMargin.closePosition(trader, toWei("0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1050")); // + 100 * 0.5
            expect(positionAmount).to.equal(toWei("-1"));
            expect(entryFunding).to.equal(toWei("-100"));

            await testMargin.updateUnitAccumulativeFunding(toWei("0"));
            await testMargin.closePosition(trader, toWei("0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1000")); // - 100 * 0.5
            expect(positionAmount).to.equal(toWei("-0.5"));
            expect(entryFunding).to.equal(toWei("-50"));

            await testMargin.updateUnitAccumulativeFunding(toWei("-100"));
            await testMargin.closePosition(trader, toWei("0.5"));
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("900")); // - 100 * 0.5
            expect(positionAmount).to.equal(toWei("0"));
            expect(entryFunding).to.equal(toWei("0"));
        })

        it("wrong side", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.openPosition(trader, toWei("-2"));
            await expect(testMargin.openPosition(trader, toWei("2"))).to.be.revertedWith("must open position");
            await expect(testMargin.closePosition(trader, toWei("-2"))).to.be.revertedWith("must close position");
        })

        it("updateMarginAccount", async () => {
            let trader = accounts[0].address;
            await testMargin.updateMarkPrice(toWei("500"));
            await testMargin.updateUnitAccumulativeFunding(toWei("100"));
            await testMargin.initializeMarginAccount(trader, toWei("1000"), toWei("0"), toWei("0"));

            await testMargin.updateMarginAccount(trader, toWei("2"), toWei("100"))
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1100"));
            expect(positionAmount).to.equal(toWei("2"));
            expect(entryFunding).to.equal(toWei("200"));

            await testMargin.updateUnitAccumulativeFunding(toWei("200"));
            await testMargin.updateMarginAccount(trader, toWei("0.5"), toWei("100"))
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1200"));
            expect(positionAmount).to.equal(toWei("2.5"));
            expect(entryFunding).to.equal(toWei("300"));

            await testMargin.updateUnitAccumulativeFunding(toWei("0"));
            await testMargin.updateMarginAccount(trader, toWei("-1"), toWei("-100"))
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1220"));
            expect(positionAmount).to.equal(toWei("1.5"));
            expect(entryFunding).to.equal(toWei("180"));

            await testMargin.updateUnitAccumulativeFunding(toWei("-100"));
            await testMargin.updateMarginAccount(trader, toWei("-5"), toWei("-100"))
            var { cashBalance, positionAmount, entryFunding } = await testMargin.marginAccount(trader);
            expect(cashBalance).to.equal(toWei("1450")); // 1220 -100 + (-100 * -1.5 - -180 = 1120 + 150 + 180 = 1450
            expect(positionAmount).to.equal(toWei("-3.5"));
            expect(entryFunding).to.equal(toWei("350"));
        })
    })
})