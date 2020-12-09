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
        let user1;
        let user2;
        let user3;
        let user4;
        let user5;
        let none = "0x0000000000000000000000000000000000000000";

        let testTrade;

        beforeEach(async () => {
            const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            const oracle = await createContract("OracleWrapper", [erc20.address]);
            const FundingModule = await createContract("FundingModule");
            const ParameterModule = await createContract("ParameterModule");
            const AMMModule = await createContract("AMMModule");
            const TradeModule = await createContract("TradeModule", [], { AMMModule });
            testTrade = await createContract("TestTrade", [oracle.address], { FundingModule, ParameterModule, TradeModule });

            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];
        })

        it('updateTradingFees', async () => {
            const coreParameters = {
                initialMarginRate: toWei("0.1"),
                maintenanceMarginRate: toWei("0.05"),
                liquidationPenaltyRate: toWei("0.005"),
                keeperGasReward: toWei("1"),
                lpFeeRate: toWei("0.0007"),
                operatorFeeRate: toWei("0.0001"),
                referrerRebateRate: toWei("0"),
            }
            for (var key in coreParameters) {
                await testTrade.updateMarketParameter(toBytes32(key), coreParameters[key]);
            }
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradingValue: toWei("10000"),
                tradingAmount: toWei("0"),
                lpFee: toWei("0"),
                vaultFee: toWei("0"),
                operatorFee: toWei("0"),
                referrerFee: toWei("0"),
                takerOpeningAmount: toWei("0"),
                makerOpeningAmount: toWei("0"),
                takerClosingAmount: toWei("0"),
                makerClosingAmount: toWei("0"),
                takerFundingLoss: toWei("0"),
                makerFundingLoss: toWei("0"),
            }
            var result = await testTrade.updateTradingFees(receipt, none);
            expect(result.lpFee).to.equal(toWei("7"));
            expect(result.vaultFee).to.equal(toWei("2"));
            expect(result.operatorFee).to.equal(toWei("1"));
            expect(result.referrerFee).to.equal(toWei("0"));

            await testTrade.updateMarketParameter(toBytes32("referrerRebateRate"), toWei("0.5"));
            var result = await testTrade.updateTradingFees(receipt, none);
            expect(result.lpFee).to.equal(toWei("7"));
            expect(result.vaultFee).to.equal(toWei("2"));
            expect(result.operatorFee).to.equal(toWei("1"));
            expect(result.referrerFee).to.equal(toWei("0"));

            var result = await testTrade.updateTradingFees(receipt, user1.address);
            expect(result.lpFee).to.equal(toWei("3.5"));
            expect(result.vaultFee).to.equal(toWei("2"));
            expect(result.operatorFee).to.equal(toWei("0.5"));
            expect(result.referrerFee).to.equal(toWei("4"));
        })

        it('validatePrice', async () => {
            await testTrade.validatePrice(1, toWei("100"), toWei("100"));
            await testTrade.validatePrice(1, toWei("90"), toWei("100"));
            await testTrade.validatePrice(-1, toWei("110"), toWei("100"));

            await expect(testTrade.validatePrice(1, toWei("0"), toWei("100"))).to.be.revertedWith("price is 0")
            await expect(testTrade.validatePrice(1, toWei("100.1"), toWei("100"))).to.be.revertedWith("too high");
            await expect(testTrade.validatePrice(-1, toWei("99.9"), toWei("100"))).to.be.revertedWith("too low");
        })

        it("updateTradingResult - case 1", async () => {
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradingValue: toWei("10000"),
                tradingAmount: toWei("-5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
                takerOpeningAmount: toWei("0"),
                makerOpeningAmount: toWei("0"),
                takerClosingAmount: toWei("0"),
                makerClosingAmount: toWei("0"),
                takerFundingLoss: toWei("0"),
                makerFundingLoss: toWei("0"),
            }
            await testTrade.updateTradingResult(receipt, user1.address, user2.address, user5.address)
            var result = await testTrade.tempReceipt();

            expect(await testTrade.claimableFees(user3.address)).to.equal(toWei("3"));
            expect(await testTrade.claimableFees(user4.address)).to.equal(toWei("2"));
            expect(await testTrade.claimableFees(user5.address)).to.equal(toWei("4"));

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user1.address);
            expect(cashBalance).to.equal(toWei("-10010"));
            expect(positionAmount).to.equal(toWei("5"));
            expect(result.takerOpeningAmount).to.equal(toWei("5"))
            expect(result.takerClosingAmount).to.equal(toWei("0"))
            expect(result.takerFundingLoss).to.equal(toWei("0"))

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user2.address);
            expect(cashBalance).to.equal(toWei("10001"));
            expect(positionAmount).to.equal(toWei("-5"));
            expect(result.makerOpeningAmount).to.equal(toWei("-5"))
            expect(result.makerClosingAmount).to.equal(toWei("0"))
            expect(result.makerFundingLoss).to.equal(toWei("0"))
        })

        it("updateTradingResult - case 2", async () => {
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradingValue: toWei("-10000"),
                tradingAmount: toWei("5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
                takerOpeningAmount: toWei("0"),
                makerOpeningAmount: toWei("0"),
                takerClosingAmount: toWei("0"),
                makerClosingAmount: toWei("0"),
                takerFundingLoss: toWei("0"),
                makerFundingLoss: toWei("0"),
            }

            await testTrade.updateTradingResult(receipt, user1.address, user2.address, user5.address)
            var result = await testTrade.tempReceipt();

            expect(await testTrade.claimableFees(user3.address)).to.equal(toWei("3"));
            expect(await testTrade.claimableFees(user4.address)).to.equal(toWei("2"));
            expect(await testTrade.claimableFees(user5.address)).to.equal(toWei("4"));

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user1.address);
            expect(cashBalance).to.equal(toWei("9990"));
            expect(positionAmount).to.equal(toWei("-5"));
            expect(result.takerOpeningAmount).to.equal(toWei("-5"))
            expect(result.takerClosingAmount).to.equal(toWei("0"))
            expect(result.takerFundingLoss).to.equal(toWei("0"))

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user2.address);
            expect(cashBalance).to.equal(toWei("-9999"));
            expect(positionAmount).to.equal(toWei("5"));
            expect(result.makerOpeningAmount).to.equal(toWei("5"))
            expect(result.makerClosingAmount).to.equal(toWei("0"))
            expect(result.makerFundingLoss).to.equal(toWei("0"))
        })

        it("updateTradingResult - case 3", async () => {
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradingValue: toWei("10000"),
                tradingAmount: toWei("-5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
                takerOpeningAmount: toWei("0"),
                makerOpeningAmount: toWei("0"),
                takerClosingAmount: toWei("0"),
                makerClosingAmount: toWei("0"),
                takerFundingLoss: toWei("0"),
                makerFundingLoss: toWei("0"),
            }
            await testTrade.updateUnitAccumulativeFunding(toWei("100"));

            await testTrade.initializeMarginAccount(user1.address, toWei("5000"), toWei("-4"), toWei("0"))
            await testTrade.initializeMarginAccount(user2.address, toWei("2000"), toWei("2"), toWei("0"))

            await testTrade.updateTradingResult(receipt, user1.address, user2.address, user5.address)
            var result = await testTrade.tempReceipt();

            expect(await testTrade.claimableFees(user3.address)).to.equal(toWei("3"));
            expect(await testTrade.claimableFees(user4.address)).to.equal(toWei("2"));
            expect(await testTrade.claimableFees(user5.address)).to.equal(toWei("4"));

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user1.address);
            expect(cashBalance).to.equal(toWei("-4610")); // 5000 - 10000(cash) - 10(fee) - (100 * -4)
            expect(positionAmount).to.equal(toWei("1"));
            expect(result.takerOpeningAmount).to.equal(toWei("1"))
            expect(result.takerClosingAmount).to.equal(toWei("4"))
            expect(result.takerFundingLoss).to.equal(toWei("-400"))

            var { cashBalance, positionAmount } = await testTrade.marginAccount(user2.address);
            expect(cashBalance).to.equal(toWei("11801")); // 2000 + 10000(cash) + 1 - (100 * 2)
            expect(positionAmount).to.equal(toWei("-3"));
            expect(result.makerOpeningAmount).to.equal(toWei("-3"))
            expect(result.makerClosingAmount).to.equal(toWei("-2"))
            expect(result.makerFundingLoss).to.equal(toWei("200"))
        })
    })

    describe("trade", async () => {

        let user1;
        let user2;
        let user3;
        let user4;
        let user5;
        let testTrade;

        beforeEach(async () => {
            const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            const oracle = await createContract("OracleWrapper", [erc20.address]);
            const FundingModule = await createContract("FundingModule");
            const ParameterModule = await createContract("ParameterModule");
            const AMMModule = await createContract("AMMModule");
            const TradeModule = await createContract("TradeModule", [], { AMMModule });
            testTrade = await createContract("TestTrade", [oracle.address], { FundingModule, ParameterModule, TradeModule });

            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];
        })

        const coreParameters = {
            initialMarginRate: toWei("0.1"),
            maintenanceMarginRate: toWei("0.05"),
            liquidationPenaltyRate: toWei("0.005"),
            keeperGasReward: toWei("1"),
            lpFeeRate: toWei("0.0007"),
            operatorFeeRate: toWei("0.0001"),
            referrerRebateRate: toWei("0"),
        }
        const riskParameters = {
            halfSpreadRate: toWei("0.001"),
            beta1: toWei("0.2"),
            beta2: toWei("0.1"),
            fundingRateCoefficient: toWei("0.005"),
            targetLeverage: toWei("5"),
        }
        const testCases = [
            {
                name: "sell",
                marginAccount: {
                    cashBalance: toWei('7699.77'), // 10000 - 2300.23
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("-0.5"),
                    priceLimit: toWei("0"),
                },
                expectOutput: {
                    cashBalance: toWei("10942.018650184354801467"),
                    ammCashBalance: toWei("4451.395359950153748472"),
                }
            },
            {
                name: "sell - close mm unsafe",
                marginAccount: {
                    cashBalance: toWei('-15443'),   // 16070.23 . mm == 626.85
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("-0.5"),
                    priceLimit: toWei("0"),
                },
                expectOutput: {
                    cashBalance: toWei("-12200.751349815645198533"),
                    ammCashBalance: toWei("4451.395359950153748472"),
                }
            },
            {
                name: "sell - margin unsafe",
                marginAccount: {
                    cashBalance: toWei('-15761'),   // 16070.23 . mm == 626.85
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("-0.5"),
                    priceLimit: toWei("0"),
                },
                expectError: "trader margin is unsafe"
            },
            {
                name: "buy without cross 0",
                marginAccount: {
                    cashBalance: toWei('7699.77'), // 10000 - 2300.23
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("0.5"),
                    priceLimit: toWei("99999999999999"),
                },
                expectOutput: {
                    cashBalance: toWei("4292.448765679380144733"),
                    ammCashBalance: toWei("11100.919264288562248655"),
                }
            },
            {
                name: "buy - open im unsafe",
                marginAccount: {
                    cashBalance: toWei('-14121'),
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("0.5"),
                    priceLimit: toWei("99999999999999"),
                },
                expectError: "trader initial margin is unsafe",
            },
            {
                name: "buy cross 0",
                marginAccount: {
                    cashBalance: toWei('7699.77'), // 10000 - 2300.23
                    positionAmount: toWei('2.3'),
                    entryFunding: toWei('-0.91'),
                },
                input: {
                    amount: toWei("3.3"),
                    priceLimit: toWei("99999999999999"),
                },
                expectOutput: {
                    cashBalance: toWei("-15287.812508807433237139"),
                    ammCashBalance: toWei("30656.769467190158282122"),
                }
            },
        ]

        testCases.forEach((testCase) => {
            it(testCase.name, async () => {
                for (var key in coreParameters) {
                    await testTrade.updateMarketParameter(toBytes32(key), coreParameters[key]);
                }
                await testTrade.setVault(user4.address, toWei("0.0002"))
                for (var key in riskParameters) {
                    await testTrade.updateMarketRiskParameter(toBytes32(key), riskParameters[key]);
                }
                await testTrade.updateUnitAccumulativeFunding(toWei("9.9059375"))
                await testTrade.updateMarkPrice(toWei("6965"));
                await testTrade.updateIndexPrice(toWei("7000"));
                await testTrade.initializeMarginAccount(
                    testTrade.address,
                    toWei('7699.77'),
                    toWei('2.3'),
                    toWei('-0.91'));
                await testTrade.initializeMarginAccount(
                    user1.address,
                    testCase.marginAccount.cashBalance,
                    testCase.marginAccount.positionAmount,
                    testCase.marginAccount.entryFunding);
                if (typeof testCase.expectOutput != "undefined") {
                    await testTrade.trade(user1.address, testCase.input.amount, testCase.input.priceLimit, user5.address);
                    // console.log(fromWei(await testTrade.callStatic.margin(user1.address)));
                    var { cashBalance } = await testTrade.marginAccount(user1.address);
                    expect(cashBalance).approximateBigNumber(testCase.expectOutput.cashBalance);
                    var { cashBalance } = await testTrade.marginAccount(testTrade.address);
                    expect(cashBalance).approximateBigNumber(testCase.expectOutput.ammCashBalance);
                } else {
                    await expect(testTrade.trade(user1.address, testCase.input.amount, testCase.input.priceLimit, user5.address))
                        .to.be.revertedWith(testCase["expectError"])
                }
            })
        })
    })
})