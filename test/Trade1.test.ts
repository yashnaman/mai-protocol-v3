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
            ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            oracle = await createContract("OracleWrapper", ["CTK", "UDA"]);
            const CollateralModule = await createContract("CollateralModule")
            const AMMModule = await createContract("AMMModule", [], { CollateralModule });
            const FundingModule = await createContract("FundingModule", [], { AMMModule });
            const ParameterModule = await createContract("ParameterModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule });
            const PerpetualModule = await createContract("PerpetualModule", [], { ParameterModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], { FundingModule, ParameterModule, TradeModule, PerpetualModule });

            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];
        })

        it('updateFees', async () => {

            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
                [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            )
            await testTrade.setOperator(user0.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))

            const receipt = {
                tradeValue: toWei("10000"),
                tradeAmount: toWei("0"),
                lpFee: toWei("0"),
                vaultFee: toWei("0"),
                operatorFee: toWei("0"),
                referrerFee: toWei("0"),
            }

            await testTrade.updateFees(0, receipt, none);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("2"));
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("1"));

            await testTrade.setPerpetualParameter(0, toBytes32("referrerRebateRate"), toWei("0.5"));
            await testTrade.updateFees(0, receipt, none);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("4")); // 2+2
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("2")); // 1+1
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("0"));

            await testTrade.updateFees(0, receipt, user1.address);
            expect(await testTrade.getClaimableFee(user4.address)).to.equal(toWei("6")); // 2+2+2
            expect(await testTrade.getClaimableFee(user0.address)).to.equal(toWei("2.5")); // 1+1+0.5
            expect(await testTrade.getClaimableFee(user1.address)).to.equal(toWei("4"));
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
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
                [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            )
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradeValue: toWei("10000"),
                tradeAmount: toWei("-5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
            }
            await testTrade.updateTradingResult(0, receipt, user1.address, user2.address)

            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).to.equal(toWei("-10010"));
            expect(position).to.equal(toWei("5"));

            var { cash, position } = await testTrade.getMarginAccount(0, user2.address);
            expect(cash).to.equal(toWei("10001"));
            expect(position).to.equal(toWei("-5"));
        })

        it("updateTradingResult - case 2", async () => {
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
                [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            )
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradeValue: toWei("-10000"),
                tradeAmount: toWei("5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
            }
            await testTrade.updateTradingResult(0, receipt, user1.address, user2.address)

            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).to.equal(toWei("9990"));
            expect(position).to.equal(toWei("-5"));

            var { cash, position } = await testTrade.getMarginAccount(0, user2.address);
            expect(cash).to.equal(toWei("-9999"));
            expect(position).to.equal(toWei("5"));
        })

        it("updateTradingResult - case 3", async () => {
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
                [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            )
            await testTrade.setOperator(user3.address);
            await testTrade.setVault(user4.address, toWei("0.0002"))
            const receipt = {
                tradeValue: toWei("10000"),
                tradeAmount: toWei("-5"),
                lpFee: toWei("1"),
                vaultFee: toWei("2"),
                operatorFee: toWei("3"),
                referrerFee: toWei("4"),
            }
            await testTrade.setUnitAccumulativeFunding(0, toWei("100"));

            await testTrade.initializeMarginAccount(0, user1.address, toWei("5000"), toWei("-4"))
            await testTrade.initializeMarginAccount(0, user2.address, toWei("2000"), toWei("2"))

            await testTrade.updateTradingResult(0, receipt, user1.address, user2.address)

            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).to.equal(toWei("-4510")); // 5000 - 10000(cash) - 10(fee) + (100 * 5)(funding)
            expect(position).to.equal(toWei("1"));

            var { cash, position } = await testTrade.getMarginAccount(0, user2.address);
            expect(cash).to.equal(toWei("11501")); // 2000 + 10000(cash) + 1 + (100 * -5)
            expect(position).to.equal(toWei("-3"));
        })
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
            const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            oracle = await createContract("OracleWrapper", ["CTK", "UDA"]);
            const CollateralModule = await createContract("CollateralModule")
            const AMMModule = await createContract("AMMModule", [], { CollateralModule });
            const FundingModule = await createContract("FundingModule", [], { AMMModule });
            const ParameterModule = await createContract("ParameterModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule });
            const PerpetualModule = await createContract("PerpetualModule", [], { ParameterModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], { FundingModule, ParameterModule, TradeModule, PerpetualModule });

            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];
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
                await testTrade.createPerpetual(
                    oracle.address,
                    // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                    [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0")],
                    // alpha
                    [toWei("0.001"), toWei("100"), toWei("90"), toWei("0.005"), toWei("5")],
                    [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
                    [toWei("0.1"), toWei("100"), toWei("100"), toWei("0.5"), toWei("10")],
                )
                await testTrade.setOperator(user3.address);
                await testTrade.setVault(user4.address, toWei("0.0002"))
                await testTrade.setUnitAccumulativeFunding(0, toWei("9.9059375"))

                let now = Math.floor(Date.now() / 1000);
                await oracle.setMarkPrice(toWei("6965"), now);
                await oracle.setIndexPrice(toWei("7000"), now);

                await testTrade.initializeMarginAccount(0, testTrade.address, toWei('83941.29865625'), toWei('2.3'));
                await testTrade.initializeMarginAccount(0, user1.address, testCase.getMarginAccount.cash, testCase.getMarginAccount.position);
                if (typeof testCase.expectOutput != "undefined") {
                    await testTrade.trade(0, user1.address, testCase.input.amount, testCase.input.limitPrice, user5.address);
                    var { cash } = await testTrade.getMarginAccount(0, user1.address);
                    expect(cash).approximateBigNumber(testCase.expectOutput.cash);
                    expect(await testTrade.getClaimableFee(user4.address)).approximateBigNumber(testCase.expectOutput.vaultFee);
                    expect(await testTrade.getClaimableFee(user3.address)).approximateBigNumber(testCase.expectOutput.operatorFee);
                } else {
                    await expect(testTrade.trade(0, user1.address, testCase.input.amount, testCase.input.limitPrice, user5.address))
                        .to.be.revertedWith(testCase["expectError"])
                }
            })
        })
    })
})