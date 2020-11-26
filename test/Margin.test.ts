import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers } from "hardhat";
import {
    toWei,
    fromWei,
    getAccounts,
    createContract,
} from './utils';

use(waffleChai);

describe('MarginModule', () => {
    var accounts;
    var testMargin;

    before(async () => {
        accounts = await getAccounts();
        const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
        const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
        testMargin = await createContract("contracts/test/TestMargin.sol:TestMargin", [], {
            FundingModule: FundingModule.address,
            ParameterModule: ParameterModule.address,
        });
    })

    describe('getter', async () => {
        await testMargin.updateMarkPrice(toWei("500"));
        const testCases = [
            {
                method: "initialMargin",
                markPrice: toWei("500"),
                marginAccount: {
                    cashBalance: toWei("100"),
                    positionAmount: toWei("1"),
                    entryFunding: toWei("0"),
                },
                unitAccumulativeFunding: toWei("0"),
                trader: accounts[0].address,
                expect: ""
            }
        ]
        testCases.forEach((testCase) => {
            it(testCase.method, async () => {
                await testMargin.updateMarkPrice(testCase.markPrice);
                await testMargin.updateMarginAccount(
                    testCase.trader,
                    testCase.marginAccount.cashBalance,
                    testCase.marginAccount.positionAmount,
                    testCase.marginAccount.entryFunding);
                await testMargin.updateUnitAccumulativeFunding(testCase.unitAccumulativeFunding);
                const result = await testMargin[testCase.method](testCase.trader);
                console.log(result)
                expect(result).to.equal(testCase.expect)
            })
        })
    })
})