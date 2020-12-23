import BigNumber from 'bignumber.js';
import { ethers } from "hardhat";
import { expect } from "chai";

import "./helper";
import { createContract } from '../scripts/utils';

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { TestShareTokenFactory } from "../typechain/TestShareTokenFactory"
import { TestAmmFactory } from "../typechain/TestAmmFactory"

const weis = new BigNumber('1000000000000000000');
const toWad = (x: any) => {
    return new BigNumber(x).times(weis).toFixed(0);
}
const _0 = toWad('0')

const params = {
    unitAccumulativeFunding: toWad('1.9'),
    halfSpread: toWad('0.001'),
    openSlippageFactor: toWad('100'),
    closeSlippageFactor: toWad('90'),
    ammMaxLeverage: toWad('5'),
    indexPrice: toWad('100')
}

// [-2] emergency
const ammEmergency = {
    cashBalance: toWad('10000'),
    positionAmount1: toWad('-50'),
    positionAmount2: toWad('-52'),
    // available cash = 10000 - 1.9 * (-50) - 1.9 * (-52) = 10193.8
    // pool margin = emergency
}

// [-1] init
const ammInit = {
    cashBalance: _0,
    positionAmount1: _0,
    positionAmount2: _0,
    // available cash = 0
    // pool margin = 0
}

// [0] flat
const amm0 = {
    cashBalance: toWad('10000'),
    positionAmount1: _0,
    positionAmount2: _0,
    // available cash = 10000
    // pool margin = 10000
}

// [1] short 1: normal
const amm1 = {
    cashBalance: toWad('10100'),
    positionAmount1: toWad('-10'),
    positionAmount2: toWad('10'),
    // available cash = 10100 - 1.9 * (-10) - 1.9 * (10) = 10100
    // pool margin = 10000
}

// [2] short 2: loss but safe
const amm2 = {
    cashBalance: toWad('14599'),
    positionAmount1: toWad('-50'),
    positionAmount2: toWad('10'),
    // available cash = 14599 - 1.9 * (-50) - 1.9 * (10) = 14675
    // pool margin = 9273.09477715884768908142691791
}

// [3] short 3: unsafe
const amm3 = {
    cashBalance: toWad('17692'),
    positionAmount1: toWad('-80'),
    positionAmount2: toWad('10'),
    // available cash = 17692 - 1.9 * (-80) - 1.9 * (10) = 17825
    // pool margin = unsafe
}

// [4] long 1: normal
const amm4 = {
    cashBalance: toWad('8138'),
    positionAmount1: toWad('10'),
    positionAmount2: toWad('10'),
    // available cash = 8138 - 1.9 * (10) - 1.9 * (10)= 8100
    // pool margin = 10000
}

// [5] long 2: loss but safe
const amm5 = {
    cashBalance: toWad('1664'),
    positionAmount1: toWad('50'),
    positionAmount2: toWad('10'),
    // available cash = 1664 - 1.9 * (50) - 1.9 * (10) = 1550
    // pool margin = 4893.31346231725208539935787445
}

// [6] long 3: unsafe
const amm6 = {
    cashBalance: toWad('1996'),
    positionAmount1: toWad('80'),
    positionAmount2: toWad('10'),
    // available cash = 1996 - 1.9 * (80) - 1.9 * (10) = 1825
    // pool margin = unsafe
}

// [7] negative price
const amm7 = {
    cashBalance: toWad('9733.5'),
    positionAmount1: toWad('60'),
    positionAmount2: toWad('-50'),
    // available cash = 9733.5 - 1.9 * (60) - 1.9 * (-50) = 9714.5
    // pool margin = open unsafe, close 5368.54
}

getDescription('AMM', () => {
    let amm;

    beforeEach(async () => {
        const collateralModule = await createContract("CollateralModule")
        const ammModule = await createContract("AMMModule", [], { "CollateralModule": collateralModule })
        amm = await createContract("TestAMM", [], { "AMMModule": ammModule });
    });

    getDescription('isAMMSafe', function () {

        const cases = [
            {
                name: 'init - ok',
                amm: ammInit,
                isSafe: true
            },
            {
                name: 'flat - ok',
                amm: amm0,
                isSafe: true
            },
            {
                name: 'short - ok',
                amm: amm1,
                isSafe: true
            },
            {
                name: 'short - fail',
                amm: amm3,
                isSafe: false
            },
            {
                name: 'long - ok',
                amm: amm4,
                isSafe: true
            },
            {
                name: 'long - fail',
                amm: amm6,
                isSafe: false
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                if (element.isSafe) {
                    expect(await amm.isAMMMarginSafe()).to.be.true
                } else {
                    expect(await amm.isAMMMarginSafe()).to.be.false
                }
            })
        })
    })

    getDescription('regress', function () {

        const successCases = [
            {
                amm: ammInit,
                poolMargin: _0,
            },
            {
                amm: amm0,
                poolMargin: toWad('10000'),
            },
            {
                amm: amm1,
                poolMargin: toWad('10000'),
            },
            {
                amm: amm2,
                poolMargin: toWad(' 9273.09477715884768908142691791'),
            },
            {
                amm: amm4,
                poolMargin: toWad('10000'),
            },
            {
                amm: amm5,
                poolMargin: toWad('4893.31346231725208539935787445'),
            }
        ]

        successCases.forEach((element, index) => {
            it(`success-${index}`, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                expect(await amm.regress()).approximateBigNumber(element.poolMargin);
            })
        })

        const failCases = [
            {
                name: 'short unsafe',
                amm: amm3
            },
            {
                name: 'long unsafe',
                amm: amm6
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                await expect(amm.regress()).to.be.revertedWith('amm is unsafe when regress')
            })
        })
    })

    getDescription('deltaMargin', function () {

        const cases = [
            {
                name: '0 -> +5',
                amm: amm0,
                amount: toWad('5'),
                deltaMargin: toWad('-487.5')
            },
            {
                name: '0 -> -5',
                amm: amm0,
                amount: toWad('-5'),
                deltaMargin: toWad('512.5')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                expect(await amm.deltaMargin(element.amount)).approximateBigNumber(element.deltaMargin)
            })
        })
    })

    getDescription('safePosition', function () {
        const cases = [
            {
                name: 'init',
                amm: ammInit,
                isLongSide: false,
                ammMaxLeverage: params.ammMaxLeverage,
                positionAmount2: ammInit.positionAmount2,
                maxPosition: _0
            },
            {
                name: 'short, infinite max position2, choose max position1',
                amm: amm1,
                isLongSide: false,
                ammMaxLeverage: params.ammMaxLeverage,
                positionAmount2: amm1.positionAmount2,
                maxPosition: toWad('-141.067359796658844252321636909')
            },
            {
                name: 'short, choose max position1',
                amm: amm1,
                isLongSide: false,
                ammMaxLeverage: toWad('0.991'),
                positionAmount2: toWad('200'),
                maxPosition: toWad('-128.653323548597695348814505356')
            },
            {
                name: 'short, choose max position2',
                amm: amm1,
                isLongSide: false,
                ammMaxLeverage: toWad('0.5'),
                positionAmount2: amm1.positionAmount2,
                maxPosition: toWad('-45.403751662596934803491571167')
            },
            {
                name: 'long, choose max position3',
                amm: amm4,
                isLongSide: true,
                ammMaxLeverage: params.ammMaxLeverage,
                positionAmount2: amm4.positionAmount2,
                maxPosition: toWad('100')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, element.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.positionAmount2, params.indexPrice, params.indexPrice)
                expect(await amm.maxPosition(element.isLongSide)).approximateBigNumber(element.maxPosition)
            })
        })

        it('zero index price', async () => {
            await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, amm1.cashBalance, amm1.positionAmount1, amm1.positionAmount2, _0, params.indexPrice)
            await expect(amm.maxPosition(0)).to.be.revertedWith('index price must be positive')
        })
    })

    getDescription('trade - success', function () {

        const successCases = [
            {
                name: 'open 0 -> -141.421',
                amm: amm0,
                amount: toWad('-141.421'),
                partialFill: false,
                deltaMargin: toWad('24166.1916701205'), // trader buy, 24142.0496205 (1 + α)
                deltaPosition: toWad('-141.421')
            },
            {
                name: 'open -10 -> -141.067',
                amm: amm1,
                amount: toWad('-131.067'),
                partialFill: false,
                deltaMargin: toWad('23029.6558937445'), // trader buy, 23006.6492445 (1 + α)
                deltaPosition: toWad('-131.067')
            },
            {
                name: 'open 0 -> 100',
                amm: amm0,
                amount: toWad('100'),
                deltaMargin: toWad('-4995'), // trader sell, -5000 (1 - α)
                deltaPosition: toWad('100')
            },
            {
                name: 'open 10 -> 100',
                amm: amm4,
                amount: toWad('90'),
                deltaMargin: toWad('-4045.95'), // trader sell, -4050 (1 - α)
                deltaPosition: toWad('90')
            },
            {
                name: 'close -10 -> -9',
                amm: amm1,
                amount: toWad('1'),
                deltaMargin: toWad('-108.4371405102481132569021'), // trader sell, -108.5456861964445578147169 (1 - α)
                deltaPosition: toWad('1')
            },
            {
                name: 'close -10 -> 0',
                amm: amm1,
                amount: toWad('10'),
                deltaMargin: toWad('-1043.932318474990069773169'), // trader sell, -1044.977295770760830603773 (1 - α)
                deltaPosition: toWad('10')
            },
            {
                name: 'close 10 -> 9',
                amm: amm4,
                amount: toWad('-1'),
                deltaMargin: toWad('91.5457681173589976274684'), // trader buy, 91.4543138035554421852831 (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'close 10 -> 0',
                amm: amm4,
                amount: toWad('-10'),
                deltaMargin: toWad('955.977726933468408565623'), // trader buy, 955.022704229239169396227 (1 + α)
                deltaPosition: toWad('-10')
            },
            {
                name: 'close unsafe -10 -> -9',
                amm: amm3,
                amount: toWad('1'),
                deltaMargin: toWad('-99.9'), // trader sell, 100 (1 - α),
                deltaPosition: toWad('1')
            },
            {
                name: 'close unsafe 10 -> 9',
                amm: amm6,
                amount: toWad('-1'),
                deltaMargin: toWad('100.1'), // trader buy, 100 (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'close negative price, clip to 0',
                amm: amm7,
                amount: toWad('-0.01'),
                deltaMargin: _0, // trader buy, 0 (1 + α)
                deltaPosition: toWad('-0.01')
            },
            {
                name: 'open 0 -> -141.422, partialFill',
                amm: amm0,
                amount: toWad('-141.422'),
                partialFill: true,
                deltaMargin: toWad('24166.2777593546814385049041293'), // trader buy, 24142.1356237309504880168872421 (1 + α)
                deltaPosition: toWad('-141.421356237309504880168872421')
            },
            {
                name: 'open -10 -> -141.068, pos2 too large, partialFill',
                amm: amm1,
                amount: toWad('-131.068'),
                partialFill: true,
                deltaMargin: toWad('23029.7427156455503096573958546'), // trader buy, 23006.7359796658844252321636909 (1 + α)
                deltaPosition: toWad('-131.067359796658844252321636909')
            },
            {
                name: 'open -10 already unsafe, partialFill',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: true,
                deltaMargin: _0,
                deltaPosition: _0
            },
            {
                name: 'open 0 -> 100.001, partialFill',
                amm: amm0,
                amount: toWad('100.001'),
                partialFill: true,
                deltaMargin: toWad('-4995'), // trader sell, -5000 (1 - α)
                deltaPosition: toWad('100')
            },
            {
                name: 'open 10 -> 100.001, partialFill',
                amm: amm4,
                amount: toWad('90.001'),
                partialFill: true,
                deltaMargin: toWad('-4045.95'), // trader sell, -4050 (1 - α)
                deltaPosition: toWad('90')
            },
            {
                name: 'open 10 already unsafe, partialFill',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: true,
                deltaMargin: _0,
                deltaPosition: _0
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                const context = await amm.tradeWithAMM(element.amount, element.partialFill)
                expect(context[0]).approximateBigNumber(element.deltaMargin)
                expect(context[1]).approximateBigNumber(element.deltaPosition)
            })
        })
    })

    getDescription('trade - fail', function () {

        const failCases = [
            {
                name: 'emergency',
                amm: ammEmergency,
                amount: toWad('1'),
                partialFill: false,
                errorMsg: 'amm is emergency'
            },
            {
                name: 'zero trade amount',
                amm: amm0,
                amount: _0,
                partialFill: false,
                errorMsg: 'trade amount is zero'
            },
            {
                name: 'poolMargin = 0',
                amm: ammInit,
                amount: toWad('1'),
                partialFill: false,
                errorMsg: 'pool margin must be positive'
            },
            {
                name: 'open 0 -> -141.422, pos2 too large',
                amm: amm0,
                amount: toWad('-141.422'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open -10 -> -141.068, pos2 too large',
                amm: amm1,
                amount: toWad('-131.068'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open -10 already unsafe',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: false,
                errorMsg: 'amm is unsafe when open'
            },
            {
                name: 'open 0 -> 100.001',
                amm: amm0,
                amount: toWad('100.001'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open 10 -> 100.001',
                amm: amm4,
                amount: toWad('90.001'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open 10 already unsafe',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: false,
                errorMsg: 'amm is unsafe when open'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                await expect(amm.tradeWithAMM(element.amount, element.partialFill)).to.be.revertedWith(element.errorMsg)
            })
        })
    })

    getDescription('add liquidity', function () {

        const successCases = [
            {
                name: 'init',
                amm: ammInit,
                totalShare: _0,
                marginToAdd: toWad('1000'),
                share: toWad('1000')
            },
            {
                name: 'before safe, after safe',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                share: toWad('10.0916660306314520522392020897')
            },
            {
                name: 'short, before unsafe, after unsafe',
                amm: amm3,
                totalShare: toWad('100'),
                marginToAdd: toWad('576'),
                share: toWad('5.321016166281755196304849885')
            },
            {
                name: 'short, before unsafe, after safe',
                amm: amm3,
                totalShare: toWad('100'),
                marginToAdd: toWad('577'),
                share: toWad('6.021800176340430529365414419')
            },
            {
                name: 'long, before unsafe, after unsafe',
                amm: amm6,
                totalShare: toWad('100'),
                marginToAdd: toWad('576'),
                share: toWad('5.321016166281755196304849885')
            },
            {
                name: 'long, before unsafe, after safe',
                amm: amm6,
                totalShare: toWad('100'),
                marginToAdd: toWad('577'),
                share: toWad('6.021800176340430529365414419')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                const accounts = await ethers.getSigners();
                const user1 = accounts[1];
                const user2 = accounts[2];
                var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
                await ctk.mint(user1.address, element.marginToAdd);
                const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
                await ctkUser1.approve(amm.address, toWad("1000000"));
                var shareToken = await createContract("TestShareToken");
                await shareToken.initialize("TEST", "TEST", amm.address);
                await shareToken.setAdmin(user1.address);
                const shareTokenUser1 = await TestShareTokenFactory.connect(shareToken.address, user1);
                await shareTokenUser1.mint(user2.address, element.totalShare);
                await amm.setConfig(ctk.address, shareToken.address, 1);
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                const ammUser1 = await TestAmmFactory.connect(amm.address, user1);
                await ammUser1.addLiquidity(element.marginToAdd);
                expect(await shareToken.balanceOf(user1.address)).approximateBigNumber(element.share);
                expect(await ctk.balanceOf(user1.address)).approximateBigNumber(_0);
            })
        })

        const failCases = [
            {
                name: 'invalid margin to add',
                totalShare: toWad('100'),
                marginToAdd: _0,
                errorMsg: 'total cashAmount must be positive'
            },
            {
                name: 'poolMargin = 0 && totalShare != 0',
                totalShare: toWad('100'),
                marginToAdd: toWad('100'),
                errorMsg: 'share has no value'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                const accounts = await ethers.getSigners();
                const user1 = accounts[1];
                const user2 = accounts[2];
                var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
                await ctk.mint(user1.address, element.marginToAdd);
                const ctkUser1 = CustomErc20Factory.connect(ctk.address, user1);
                await ctkUser1.approve(amm.address, toWad("1000000"));
                var shareToken = await createContract("TestShareToken");
                await shareToken.initialize("TEST", "TEST", amm.address);
                await shareToken.setAdmin(user1.address);
                const shareTokenUser1 = TestShareTokenFactory.connect(shareToken.address, user1);
                await shareTokenUser1.mint(user2.address, element.totalShare);
                await amm.setConfig(ctk.address, shareToken.address, 1);
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, ammInit.cashBalance, ammInit.positionAmount1, ammInit.positionAmount2, params.indexPrice, params.indexPrice)
                const ammUser1 = TestAmmFactory.connect(amm.address, user1);
                await expect(ammUser1.addLiquidity(element.marginToAdd)).to.be.revertedWith(element.errorMsg);
            })
        })
    })

    getDescription('remove liquidity', function () {

        const successCases = [
            {
                name: 'poolMargin = 0',
                amm: ammInit,
                restShare: toWad('90'), // total 100
                shareToRemove: toWad('10'),
                marginToRemove: _0
            },
            {
                name: 'no position',
                amm: amm0,
                restShare: toWad('90'), // total 100
                shareToRemove: toWad('10'),
                marginToRemove: toWad('1000')
            },
            {
                name: 'no position, remove all',
                amm: amm0,
                restShare: _0, // total 100
                shareToRemove: toWad('100'),
                marginToRemove: toWad('10000')
            },
            {
                name: 'short',
                amm: amm1,
                restShare: toWad('90'), // total 100
                shareToRemove: toWad('10'),
                marginToRemove: toWad('988.888888888888888888888888889')
            },
            {
                name: 'long',
                amm: amm4,
                restShare: toWad('90'), // total 100
                shareToRemove: toWad('10'),
                marginToRemove: toWad('988.888888888888888888888888889')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                const accounts = await ethers.getSigners();
                const user1 = accounts[1];
                const user2 = accounts[2];
                var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
                await ctk.mint(amm.address, element.marginToRemove);
                var shareToken = await createContract("TestShareToken");
                await shareToken.initialize("TEST", "TEST", amm.address);
                await shareToken.setAdmin(user1.address);
                const shareTokenUser1 = TestShareTokenFactory.connect(shareToken.address, user1);
                await shareTokenUser1.mint(user1.address, element.shareToRemove);
                await shareTokenUser1.mint(user2.address, element.restShare);
                await amm.setConfig(ctk.address, shareToken.address, 1);
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                const ammUser1 = TestAmmFactory.connect(amm.address, user1);
                await ammUser1.removeLiquidity(element.shareToRemove);
                expect(await ctk.balanceOf(user1.address)).approximateBigNumber(element.marginToRemove);
                expect(await shareToken.balanceOf(user1.address)).approximateBigNumber(_0);
                expect(await shareToken.totalSupply()).approximateBigNumber(element.restShare);
            })
        })

        const failCases = [
            {
                name: 'zero share to remove',
                amm: amm0,
                restShare: toWad('100'), // total 100
                shareBalance: _0,
                shareToRemove: _0,
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'share to remove must be positive',
            },
            {
                name: 'insufficient share balance',
                amm: amm0,
                restShare: _0, // total 100
                shareBalance: toWad('100'),
                shareToRemove: toWad('100.1'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'insufficient share balance',
            },
            {
                name: 'short, before unsafe',
                amm: amm3,
                restShare: toWad('90'), // total 100
                shareBalance: toWad('10'),
                shareToRemove: toWad('10'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'amm is unsafe before removing liquidity',
            },
            {
                name: 'long, before unsafe',
                amm: amm6,
                restShare: toWad('90'), // total 100
                shareBalance: toWad('10'),
                shareToRemove: toWad('10'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'amm is unsafe before removing liquidity',
            },
            {
                name: 'short, after unsafe',
                amm: amm1,
                restShare: toWad('9.999'), // total 100
                shareBalance: toWad('90.001'),
                shareToRemove: toWad('90.001'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after unsafe',
                amm: amm4,
                restShare: toWad('9.999'), // total 100
                shareBalance: toWad('90.001'),
                shareToRemove: toWad('90.001'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after negative price',
                amm: amm5,
                restShare: toWad('99.999'), // total 100
                shareBalance: toWad('0.001'),
                shareToRemove: toWad('0.001'),
                ammMaxLeverage: params.ammMaxLeverage,
                errorMsg: 'amm is unsafe after removing liquidity',
            },
            {
                name: 'long, after exceed leverage',
                amm: amm4,
                restShare: toWad('99.999'), // total 100
                shareBalance: toWad('0.001'),
                shareToRemove: toWad('0.001'),
                ammMaxLeverage: toWad('0.1'),
                errorMsg: 'amm exceeds max leverage after removing liquidity',
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                const accounts = await ethers.getSigners();
                const user1 = accounts[1];
                const user2 = accounts[2];
                var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
                var shareToken = await createContract("TestShareToken");
                await shareToken.initialize("TEST", "TEST", amm.address);
                await shareToken.setAdmin(user1.address);
                const shareTokenUser1 = await TestShareTokenFactory.connect(shareToken.address, user1);
                await shareTokenUser1.mint(user1.address, element.shareBalance);
                await shareTokenUser1.mint(user2.address, element.restShare);
                await amm.setConfig(ctk.address, shareToken.address, 1);
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, element.ammMaxLeverage, element.amm.cashBalance, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                const ammUser1 = await TestAmmFactory.connect(amm.address, user1);
                await expect(ammUser1.removeLiquidity(element.shareToRemove)).to.be.revertedWith(element.errorMsg);
            })
        })
    })
});
