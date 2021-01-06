import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    fromBytes32,
    toBytes32,
    getAccounts,
    createFactory,
    createContract,
} from '../scripts/utils';

import "./helper";

describe('LiquidityPool', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let user4;
    let user5;

    let liquidityPool;
    let oracle1;
    let oracle2;
    let ctk;
    let stk;

    before(async () => {
        accounts = await getAccounts();
    })

    beforeEach(async () => {
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        user4 = accounts[4];
        user5 = accounts[5];

        const CollateralModule = await createContract("CollateralModule")
        const PerpetualModule = await createContract("PerpetualModule");
        const AMMModule = await createContract("AMMModule");
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], {
            AMMModule,
            CollateralModule,
            PerpetualModule
        });
        liquidityPool = await createContract("TestLiquidityPool", [], {
            LiquidityPoolModule,
            PerpetualModule
        });

        stk = await createContract("TestShareToken");
        await stk.initialize("TEST", "TEST", liquidityPool.address);

        await liquidityPool.setShareToken(stk.address);

        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        await liquidityPool.setCollateralToken(ctk.address, 18);

        oracle1 = await createContract("OracleWrapper", ["ctk", "ctk"]);
        await liquidityPool.createPerpetual(
            oracle1.address,
            // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
            [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
            [toWei("0.001"), toWei("1"), toWei("0.9"), toWei("5"), toWei("5"), toWei('0.2')],
        )
        oracle2 = await createContract("OracleWrapper", ["ctk", "ctk"]);
        await liquidityPool.createPerpetual(
            oracle2.address,
            // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
            [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
            [toWei("0.001"), toWei("1"), toWei("0.9"), toWei("5"), toWei("5"), toWei('0.2')],
        )
    })

    describe('liquidity', function () {
        const successCases = [
            {
                name: 'init',
                amm: {
                    cash: 0,
                    position1: 0,
                    position2: 0,
                },
                totalShare: 0,
                marginToAdd: toWei('1000'),
                share: toWei('1000')
            },
            {
                name: 'before safe, after safe',
                amm: {
                    cash: toWei("10100"),
                    position1: toWei("-10"),
                    position2: toWei("10"),
                },
                totalShare: toWei('100'), // oracle = 10 0
                marginToAdd: toWei('1000'),
                share: toWei('10.091666030631452052')
            },
            {
                name: 'short, before unsafe, after unsafe',
                amm: {
                    cash: toWei("17692"),
                    position1: toWei("-80"),
                    position2: toWei("10"),
                },
                totalShare: toWei('100'),
                marginToAdd: toWei('576'),
                share: toWei('5.321016166281755196')
            },
            {
                name: 'short, before unsafe, after safe',
                amm: {
                    cash: toWei("17692"),
                    position1: toWei("-80"),
                    position2: toWei("10"),
                },
                totalShare: toWei('100'),
                marginToAdd: toWei('577'),
                share: toWei('6.021800176340430529')
            },
            {
                name: 'long, before unsafe, after unsafe',
                amm: {
                    cash: toWei('1996'),
                    position1: toWei('80'),
                    position2: toWei('10'),
                },
                totalShare: toWei('100'),
                marginToAdd: toWei('576'),
                share: toWei('5.321016166281755196')
            },
            {
                name: 'long, before unsafe, after safe',
                amm: {
                    cash: toWei('1996'),
                    position1: toWei('80'),
                    position2: toWei('10'),
                },
                totalShare: toWei('100'),
                marginToAdd: toWei('577'),
                share: toWei('6.021800176340430529')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await liquidityPool.setState(0, 2);
                await liquidityPool.setState(1, 2);

                await ctk.mint(user1.address, element.marginToAdd);
                await ctk.connect(user1).approve(liquidityPool.address, toWei("1000000"));
                await stk.debugMint(user2.address, element.totalShare);

                await liquidityPool.setPoolCash(element.amm.cash)
                await liquidityPool.setMarginAccount(0, liquidityPool.address, 0, element.amm.position1);
                await liquidityPool.setMarginAccount(1, liquidityPool.address, 0, element.amm.position2);
                await liquidityPool.setUnitAccumulativeFunding(0, toWei("1.9"));
                await liquidityPool.setUnitAccumulativeFunding(1, toWei("1.9"));

                let now = Math.floor(Date.now() / 1000);
                await oracle1.setIndexPrice(toWei('100'), now);
                await oracle1.setMarkPrice(toWei('100'), now);
                await oracle2.setIndexPrice(toWei('100'), now);
                await oracle2.setMarkPrice(toWei('100'), now);
                await liquidityPool.updatePrice(now);

                await liquidityPool.addLiquidity(user1.address, element.marginToAdd);
                expect(await stk.balanceOf(user1.address)).approximateBigNumber(element.share);
                expect(await ctk.balanceOf(user1.address)).approximateBigNumber("0");
            })
        })

        const failCases = [
            {
                name: 'invalid margin to add',
                totalShare: toWei('100'),
                marginToAdd: toWei("0"),
                errorMsg: 'cash amount must be positive'
            },
            {
                name: 'poolMargin = 0 && totalShare != 0',
                totalShare: toWei('100'),
                marginToAdd: toWei('100'),
                errorMsg: 'share token has no value'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await liquidityPool.setState(0, 2);
                await liquidityPool.setState(1, 2);

                await ctk.mint(user1.address, element.marginToAdd);
                await ctk.connect(user1).approve(liquidityPool.address, toWei("1000000"));
                await stk.debugMint(user2.address, element.totalShare);

                await liquidityPool.setUnitAccumulativeFunding(1, toWei("1.9"));

                let now = Math.floor(Date.now() / 1000);
                await oracle1.setIndexPrice(toWei('100'), now);
                await oracle1.setMarkPrice(toWei('100'), now);
                await oracle2.setIndexPrice(toWei('100'), now);
                await oracle2.setMarkPrice(toWei('100'), now);
                await liquidityPool.updatePrice(now);

                await expect(liquidityPool.addLiquidity(user1.address, element.marginToAdd)).to.be.revertedWith(element.errorMsg);
            })
        })

    });


    describe('remove liquidity', function () {

        const successCases = [
            {
                name: 'poolMargin = 0',
                amm: {
                    cash: toWei("0"),
                    position1: toWei("0"),
                    position2: toWei("0"),
                },
                shareLeft: toWei('90'), // total 100
                shareToRemove: toWei('10'),
                marginToRemove: toWei("0"),
            },
            {
                name: 'no position',
                amm: {
                    cash: toWei('10000'),
                    position1: toWei("0"),
                    position2: toWei("0"),
                },
                shareLeft: toWei('90'), // total 100
                shareToRemove: toWei('10'),
                marginToRemove: toWei('1000')
            },
            {
                name: 'no position, remove all',
                amm: {
                    cash: toWei('10000'),
                    position1: toWei("0"),
                    position2: toWei("0"),
                },
                shareLeft: toWei("0"), // total 100
                shareToRemove: toWei('100'),
                marginToRemove: toWei('10000')
            },
            {
                name: 'short',
                amm: {
                    cash: toWei('10100'),
                    position1: toWei("-10"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('90'), // total 100
                shareToRemove: toWei('10'),
                marginToRemove: toWei('988.888888888888888889')
            },
            {
                name: 'long',
                amm: {
                    cash: toWei('8138'),
                    position1: toWei("10"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('90'), // total 100
                shareToRemove: toWei('10'),
                marginToRemove: toWei('988.888888888888888889')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {

                await liquidityPool.setState(0, 2);
                await liquidityPool.setState(1, 2);

                await ctk.mint(liquidityPool.address, element.marginToRemove);
                await ctk.connect(user1).approve(liquidityPool.address, toWei("1000000"));
                await stk.debugMint(user1.address, element.shareToRemove);
                await stk.debugMint(user2.address, element.shareLeft);

                await liquidityPool.setPoolCash(element.amm.cash)
                await liquidityPool.setMarginAccount(0, liquidityPool.address, 0, element.amm.position1);
                await liquidityPool.setMarginAccount(1, liquidityPool.address, 0, element.amm.position2);
                await liquidityPool.setUnitAccumulativeFunding(0, toWei("1.9"));
                await liquidityPool.setUnitAccumulativeFunding(1, toWei("1.9"));

                let now = Math.floor(Date.now() / 1000);
                await oracle1.setIndexPrice(toWei('100'), now);
                await oracle1.setMarkPrice(toWei('100'), now);
                await oracle2.setIndexPrice(toWei('100'), now);
                await oracle2.setMarkPrice(toWei('100'), now);
                await liquidityPool.updatePrice(now);

                await liquidityPool.removeLiquidity(user1.address, element.shareToRemove);
                expect(await ctk.balanceOf(user1.address)).approximateBigNumber(element.marginToRemove);
                expect(await stk.balanceOf(user1.address)).approximateBigNumber(toWei("0"));
                expect(await stk.totalSupply()).approximateBigNumber(element.shareLeft);

            })
        })

        const failCases = [
            {
                name: 'zero share to remove',
                amm: {
                    cash: toWei("0"),
                    position1: toWei("0"),
                    position2: toWei("0"),
                },
                shareLeft: toWei('100'), // total 100
                shareBalance: toWei("0"),
                shareToRemove: toWei("0"),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'share to remove must be positive',
            },
            {
                name: 'insufficient share balance',
                amm: {
                    cash: toWei("0"),
                    position1: toWei("0"),
                    position2: toWei("0"),
                },
                shareLeft: toWei("0"), // total 100
                shareBalance: toWei('100'),
                shareToRemove: toWei('100.1'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'insufficient share balance',
            },
            {
                name: 'short, before unsafe',
                amm: {
                    cash: toWei("17692"),
                    position1: toWei("-80"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('90'), // total 100
                shareBalance: toWei('10'),
                shareToRemove: toWei('10'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'amm is unsafe before removing liquidity',
            },
            {
                name: 'long, before unsafe',
                amm: {
                    cash: toWei("1996"),
                    position1: toWei("80"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('90'), // total 100
                shareBalance: toWei('10'),
                shareToRemove: toWei('10'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'amm is unsafe before removing liquidity',
            },
            {
                name: 'short, after unsafe',
                amm: {
                    cash: toWei('10100'),
                    position1: toWei("-10"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('9.999'), // total 100
                shareBalance: toWei('90.001'),
                shareToRemove: toWei('90.001'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after unsafe',
                amm: {
                    cash: toWei('8138'),
                    position1: toWei("10"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('9.999'), // total 100
                shareBalance: toWei('90.001'),
                shareToRemove: toWei('90.001'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after negative price',
                amm: {
                    cash: toWei('1664'),
                    position1: toWei("50"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('99.999'), // total 100
                shareBalance: toWei('0.001'),
                shareToRemove: toWei('0.001'),
                ammMaxLeverage: toWei("5"),
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after exceed leverage',
                amm: {
                    cash: toWei('8138'),
                    position1: toWei("10"),
                    position2: toWei("10"),
                },
                shareLeft: toWei('99.999'), // total 100
                shareBalance: toWei('0.001'),
                shareToRemove: toWei('0.001'),
                ammMaxLeverage: toWei('0.1'),
                errorMsg: 'amm exceeds max leverage after removing liquidity',
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await liquidityPool.setState(0, 2);
                await liquidityPool.setState(1, 2);

                await liquidityPool.setPerpetualRiskParameter(0, toBytes32("ammMaxLeverage"), element.ammMaxLeverage, element.ammMaxLeverage, element.ammMaxLeverage);
                await liquidityPool.setPerpetualRiskParameter(1, toBytes32("ammMaxLeverage"), element.ammMaxLeverage, element.ammMaxLeverage, element.ammMaxLeverage);

                await ctk.connect(user1).approve(liquidityPool.address, toWei("1000000"));
                await stk.debugMint(user2.address, element.shareLeft);
                await stk.debugMint(user1.address, element.shareBalance);

                await liquidityPool.setPoolCash(element.amm.cash)
                await liquidityPool.setMarginAccount(0, liquidityPool.address, 0, element.amm.position1);
                await liquidityPool.setMarginAccount(1, liquidityPool.address, 0, element.amm.position2);
                await liquidityPool.setUnitAccumulativeFunding(0, toWei("1.9"));
                await liquidityPool.setUnitAccumulativeFunding(1, toWei("1.9"));

                let now = Math.floor(Date.now() / 1000);
                await oracle1.setIndexPrice(toWei('100'), now);
                await oracle1.setMarkPrice(toWei('100'), now);
                await oracle2.setIndexPrice(toWei('100'), now);
                await oracle2.setMarkPrice(toWei('100'), now);
                await liquidityPool.updatePrice(now);

                await expect(liquidityPool.removeLiquidity(user1.address, element.shareToRemove)).to.be.revertedWith(element.errorMsg);
            })
        })
    })

})