import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers } from "hardhat";
import {
    toWei,
    fromWei,
    fromBytes32,
    toBytes32,
    getAccounts,
    createContract,
} from './utils';

use(waffleChai);

describe('MarginModule', () => {
    let accounts;

    before(async () => {
        accounts = await getAccounts();
    })

    describe('getter', async () => {
        let testMargin;

        before(async () => {
            const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
            const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
            testMargin = await createContract("contracts/test/TestMargin.sol:TestMargin", [], {
                FundingModule: FundingModule.address,
                ParameterModule: ParameterModule.address,
            });
        })

        const testCases = [
            {
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
                name: "initialMargin - non-zero keeperGasReward",
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
                method: "margin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("600")
            },
            {
                method: "availableMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: 0,
                expect: toWei("550") // 500 + 50
            },
            {
                name: "positive funding",
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
                name: "negative funding",
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
                name: "negative funding - 2",
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
        ]

        testCases.forEach((testCase) => {
            it(testCase["name"] || testCase.method, async () => {
                await testMargin.updateMarkPrice(testCase.markPrice);
                await testMargin.updateMarginAccount(
                    accounts[testCase.trader].address,
                    testCase.marginAccount.cashBalance,
                    testCase.marginAccount.positionAmount,
                    testCase.marginAccount.entryFunding);
                for (var key in testCase.parameters || {}) {
                    // console.log("set", key, "=>", testCase.parameters[key].toString())
                    await testMargin.updateCoreParameter(toBytes32(key), testCase.parameters[key]);
                }
                await testMargin.updateUnitAccumulativeFunding(testCase.unitAccumulativeFunding);
                const result = await testMargin[testCase.method](accounts[testCase.trader].address);
                expect(result).to.equal(testCase.expect)
            })
        })
    })
})