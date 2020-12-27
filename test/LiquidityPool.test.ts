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

    before(async () => {
        accounts = await getAccounts();
    })

    describe('add liquidity', function () {

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

        beforeEach(async () => {
            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];

            const AMMModule = await createContract("AMMModule");
            const CollateralModule = await createContract("CollateralModule")
            const OrderModule = await createContract("OrderModule");
            const PerpetualModule = await createContract("PerpetualModule");

            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule, CollateralModule, PerpetualModule });

            liquidityPool = await createContract("TestLiquidityPool", [], {
                CollateralModule,
                LiquidityPoolModule,
                OrderModule,
                PerpetualModule,
                TradeModule,
            });

            stk = await createContract("TestShareToken");
            await stk.initialize("TEST", "TEST", liquidityPool.address);
            await liquidityPool.setShareToken(stk.address);

            ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            await liquidityPool.setCollateralToken(ctk.address, 1);

            oracle1 = await createContract("OracleWrapper", ["ctk", "ctk"]);
            await liquidityPool.createPerpetual2(
                oracle1.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.001"), toWei("100"), toWei("90"), toWei("5"), toWei("100")],
            )
            oracle2 = await createContract("OracleWrapper", ["ctk", "ctk"]);
            await liquidityPool.createPerpetual2(
                oracle2.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("1"), toWei("1"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.001"), toWei("100"), toWei("90"), toWei("5"), toWei("100")],
            )

            await liquidityPool.setUnitAccumulativeFunding(0, toWei('1.9'));
            await liquidityPool.setUnitAccumulativeFunding(1, toWei('1.9'));
        })

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
                totalShare: toWei('100'),
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
            // {
            //     name: 'long, before unsafe, after unsafe',
            //     amm: amm6,
            //     totalShare: toWei('100'),
            //     marginToAdd: toWei('576'),
            //     share: toWei('5.321016166281755196304849885')
            // },
            // {
            //     name: 'long, before unsafe, after safe',
            //     amm: amm6,
            //     totalShare: toWei('100'),
            //     marginToAdd: toWei('577'),
            //     share: toWei('6.021800176340430529365414419')
            // }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await ctk.mint(user1.address, element.marginToAdd);
                await ctk.connect(user1).approve(liquidityPool.address, toWei("1000000"));
                await stk.setTotalSupply(user2.address, element.totalShare);

                await liquidityPool.setPoolCash(element.amm.cash)
                await liquidityPool.setMarginAccount(0, liquidityPool.address, 0, element.amm.position1);
                await liquidityPool.setMarginAccount(0, liquidityPool.address, 0, element.amm.position2);

                let now = Math.floor(Date.now() / 1000);
                await oracle1.setIndexPrice(toWei('100'), now);
                await oracle1.setMarkPrice(toWei('100'), now);
                await oracle2.setIndexPrice(toWei('100'), now);
                await oracle2.setMarkPrice(toWei('100'), now);

                await liquidityPool.connect(user1).addLiquidity(element.marginToAdd);
                expect(await stk.balanceOf(user1.address)).approximateBigNumber(element.share);
                expect(await ctk.balanceOf(user1.address)).approximateBigNumber("0");
            })
        })

        // const failCases = [
        //     {
        //         name: 'invalid margin to add',
        //         totalShare: toWei('100'),
        //         marginToAdd: _0,
        //         errorMsg: 'total cashAmount must be positive'
        //     },
        //     {
        //         name: 'poolMargin = 0 && totalShare != 0',
        //         totalShare: toWei('100'),
        //         marginToAdd: toWei('100'),
        //         errorMsg: 'share has no value'
        //     }
        // ]

        // failCases.forEach(element => {
        //     it(element.name, async () => {
        //         const accounts = await ethers.getSigners();
        //         const user1 = accounts[1];
        //         const user2 = accounts[2];
        //         var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        //         await ctk.mint(user1.address, element.marginToAdd);
        //         const ctkUser1 = CustomErc20Factory.connect(ctk.address, user1);
        //         await ctkUser1.approve(amm.address, toWei("1000000"));
        //         var shareToken = await createContract("TestShareToken");
        //         await shareToken.initialize("TEST", "TEST", amm.address);
        //         await shareToken.setAdmin(user1.address);
        //         const shareTokenUser1 = TestShareTokenFactory.connect(shareToken.address, user1);
        //         await shareTokenUser1.mint(user2.address, element.totalShare);
        //         await amm.setConfig(ctk.address, shareToken.address, 1);
        //         await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, ammInit.cash, ammInit.positionAmount1, ammInit.positionAmount2, params.indexPrice, params.indexPrice)
        //         const ammUser1 = TestAmmFactory.connect(amm.address, user1);
        //         await expect(ammUser1.addLiquidity(element.marginToAdd)).to.be.revertedWith(element.errorMsg);
        //     })
        // })

        // describe('remove liquidity', function () {

        //     const successCases = [
        //         {
        //             name: 'poolMargin = 0',
        //             amm: ammInit,
        //             restShare: toWei('90'), // total 100
        //             shareToRemove: toWei('10'),
        //             marginToRemove: _0
        //         },
        //         {
        //             name: 'no position',
        //             amm: amm0,
        //             restShare: toWei('90'), // total 100
        //             shareToRemove: toWei('10'),
        //             marginToRemove: toWei('1000')
        //         },
        //         {
        //             name: 'no position, remove all',
        //             amm: amm0,
        //             restShare: _0, // total 100
        //             shareToRemove: toWei('100'),
        //             marginToRemove: toWei('10000')
        //         },
        //         {
        //             name: 'short',
        //             amm: amm1,
        //             restShare: toWei('90'), // total 100
        //             shareToRemove: toWei('10'),
        //             marginToRemove: toWei('988.888888888888888888888888889')
        //         },
        //         {
        //             name: 'long',
        //             amm: amm4,
        //             restShare: toWei('90'), // total 100
        //             shareToRemove: toWei('10'),
        //             marginToRemove: toWei('988.888888888888888888888888889')
        //         }
        //     ]

        //     successCases.forEach(element => {
        //         it(element.name, async () => {
        //             const accounts = await ethers.getSigners();
        //             const user1 = accounts[1];
        //             const user2 = accounts[2];
        //             var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        //             await ctk.mint(amm.address, element.marginToRemove);
        //             var shareToken = await createContract("TestShareToken");
        //             await shareToken.initialize("TEST", "TEST", amm.address);
        //             await shareToken.setAdmin(user1.address);
        //             const shareTokenUser1 = TestShareTokenFactory.connect(shareToken.address, user1);
        //             await shareTokenUser1.mint(user1.address, element.shareToRemove);
        //             await shareTokenUser1.mint(user2.address, element.restShare);
        //             await amm.setConfig(ctk.address, shareToken.address, 1);
        //             await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
        //             const ammUser1 = TestAmmFactory.connect(amm.address, user1);
        //             await ammUser1.removeLiquidity(element.shareToRemove);
        //             expect(await ctk.balanceOf(user1.address)).approximateBigNumber(element.marginToRemove);
        //             expect(await shareToken.balanceOf(user1.address)).approximateBigNumber(_0);
        //             expect(await shareToken.totalSupply()).approximateBigNumber(element.restShare);
        //         })
        //     })

        //     const failCases = [
        //         {
        //             name: 'zero share to remove',
        //             amm: amm0,
        //             restShare: toWei('100'), // total 100
        //             shareBalance: _0,
        //             shareToRemove: _0,
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'share to remove must be positive',
        //         },
        //         {
        //             name: 'insufficient share balance',
        //             amm: amm0,
        //             restShare: _0, // total 100
        //             shareBalance: toWei('100'),
        //             shareToRemove: toWei('100.1'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'insufficient share balance',
        //         },
        //         {
        //             name: 'short, before unsafe',
        //             amm: amm3,
        //             restShare: toWei('90'), // total 100
        //             shareBalance: toWei('10'),
        //             shareToRemove: toWei('10'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'amm is unsafe before removing liquidity',
        //         },
        //         {
        //             name: 'long, before unsafe',
        //             amm: amm6,
        //             restShare: toWei('90'), // total 100
        //             shareBalance: toWei('10'),
        //             shareToRemove: toWei('10'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'amm is unsafe before removing liquidity',
        //         },
        //         {
        //             name: 'short, after unsafe',
        //             amm: amm1,
        //             restShare: toWei('9.999'), // total 100
        //             shareBalance: toWei('90.001'),
        //             shareToRemove: toWei('90.001'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'amm is unsafe after removing liquidity',
        //         },
        //         {
        //             name: 'long, after unsafe',
        //             amm: amm4,
        //             restShare: toWei('9.999'), // total 100
        //             shareBalance: toWei('90.001'),
        //             shareToRemove: toWei('90.001'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'amm is unsafe after removing liquidity',
        //         },
        //         {
        //             name: 'long, after negative price',
        //             amm: amm5,
        //             restShare: toWei('99.999'), // total 100
        //             shareBalance: toWei('0.001'),
        //             shareToRemove: toWei('0.001'),
        //             ammMaxLeverage: params.ammMaxLeverage,
        //             errorMsg: 'amm is unsafe after removing liquidity',
        //         },
        //         {
        //             name: 'long, after exceed leverage',
        //             amm: amm4,
        //             restShare: toWei('99.999'), // total 100
        //             shareBalance: toWei('0.001'),
        //             shareToRemove: toWei('0.001'),
        //             ammMaxLeverage: toWei('0.1'),
        //             errorMsg: 'amm exceeds max leverage after removing liquidity',
        //         }
        //     ]

        //     failCases.forEach(element => {
        //         it(element.name, async () => {
        //             const accounts = await ethers.getSigners();
        //             const user1 = accounts[1];
        //             const user2 = accounts[2];
        //             var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        //             var shareToken = await createContract("TestShareToken");
        //             await shareToken.initialize("TEST", "TEST", amm.address);
        //             await shareToken.setAdmin(user1.address);
        //             const shareTokenUser1 = await TestShareTokenFactory.connect(shareToken.address, user1);
        //             await shareTokenUser1.mint(user1.address, element.shareBalance);
        //             await shareTokenUser1.mint(user2.address, element.restShare);
        //             await amm.setConfig(ctk.address, shareToken.address, 1);
        //             await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, element.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
        //             const ammUser1 = await TestAmmFactory.connect(amm.address, user1);
        //             await expect(ammUser1.removeLiquidity(element.shareToRemove)).to.be.revertedWith(element.errorMsg);
        //         })
        //     })
        // })

    })
})