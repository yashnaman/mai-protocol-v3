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
    cash: toWad('10000'),
    positionAmount1: toWad('-50'),
    positionAmount2: toWad('-52'),
    // available cash = 10000 - 1.9 * (-50) - 1.9 * (-52) = 10193.8
    // pool margin = emergency
}

// [-1] init
const ammInit = {
    cash: _0,
    positionAmount1: _0,
    positionAmount2: _0,
    // available cash = 0
    // pool margin = 0
}

// [0] flat
const amm0 = {
    cash: toWad('10000'),
    positionAmount1: _0,
    positionAmount2: _0,
    // available cash = 10000
    // pool margin = 10000
}

// [1] short 1: normal
const amm1 = {
    cash: toWad('10100'),
    positionAmount1: toWad('-10'),
    positionAmount2: toWad('10'),
    // available cash = 10100 - 1.9 * (-10) - 1.9 * (10) = 10100
    // pool margin = 10000
}

// [2] short 2: loss but safe
const amm2 = {
    cash: toWad('14599'),
    positionAmount1: toWad('-50'),
    positionAmount2: toWad('10'),
    // available cash = 14599 - 1.9 * (-50) - 1.9 * (10) = 14675
    // pool margin = 9273.09477715884768908142691791
}

// [3] short 3: unsafe
const amm3 = {
    cash: toWad('17692'),
    positionAmount1: toWad('-80'),
    positionAmount2: toWad('10'),
    // available cash = 17692 - 1.9 * (-80) - 1.9 * (10) = 17825
    // pool margin = unsafe
}

// [4] long 1: normal
const amm4 = {
    cash: toWad('8138'),
    positionAmount1: toWad('10'),
    positionAmount2: toWad('10'),
    // available cash = 8138 - 1.9 * (10) - 1.9 * (10)= 8100
    // pool margin = 10000
}

// [5] long 2: loss but safe
const amm5 = {
    cash: toWad('1664'),
    positionAmount1: toWad('50'),
    positionAmount2: toWad('10'),
    // available cash = 1664 - 1.9 * (50) - 1.9 * (10) = 1550
    // pool margin = 4893.31346231725208539935787445
}

// [6] long 3: unsafe
const amm6 = {
    cash: toWad('1996'),
    positionAmount1: toWad('80'),
    positionAmount2: toWad('10'),
    // available cash = 1996 - 1.9 * (80) - 1.9 * (10) = 1825
    // pool margin = unsafe
}

// [7] negative price
const amm7 = {
    cash: toWad('9733.5'),
    positionAmount1: toWad('60'),
    positionAmount2: toWad('-50'),
    // available cash = 9733.5 - 1.9 * (60) - 1.9 * (-50) = 9714.5
    // pool margin = open unsafe, close 5368.54
}

describe('AMM', () => {
    let amm;

    beforeEach(async () => {
        const ammModule = await createContract("AMMModule")
        amm = await createContract("TestAMM", [], { "AMMModule": ammModule });
    });

    describe('isAMMSafe', function () {

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
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                if (element.isSafe) {
                    expect(await amm.isAMMMarginSafe()).to.be.true
                } else {
                    expect(await amm.isAMMMarginSafe()).to.be.false
                }
            })
        })
    })

    describe('regress', function () {

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
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
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
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                await expect(amm.regress()).to.be.revertedWith('amm is unsafe when regress')
            })
        })
    })

    describe('deltaCash', function () {

        const cases = [
            {
                name: '0 -> +5',
                amm: amm0,
                amount: toWad('5'),
                deltaCash: toWad('-487.5')
            },
            {
                name: '0 -> -5',
                amm: amm0,
                amount: toWad('-5'),
                deltaCash: toWad('512.5')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                expect(await amm.deltaCash(element.amount)).approximateBigNumber(element.deltaCash)
            })
        })
    })

    describe('safePosition', function () {
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
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, element.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.positionAmount2, params.indexPrice, params.indexPrice)
                expect(await amm.maxPosition(element.isLongSide)).approximateBigNumber(element.maxPosition)
            })
        })

        it('zero index price', async () => {
            await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, amm1.cash, amm1.positionAmount1, amm1.positionAmount2, _0, params.indexPrice)
            await expect(amm.maxPosition(0)).to.be.revertedWith('index price must be positive')
        })
    })

    describe('trade - success', function () {

        const successCases = [
            {
                name: 'open 0 -> -141.421',
                amm: amm0,
                amount: toWad('-141.421'),
                partialFill: false,
                deltaCash: toWad('24166.1916701205'), // trader buy, 24142.0496205 (1 + α)
                deltaPosition: toWad('-141.421')
            },
            {
                name: 'open -10 -> -141.067',
                amm: amm1,
                amount: toWad('-131.067'),
                partialFill: false,
                deltaCash: toWad('23029.6558937445'), // trader buy, 23006.6492445 (1 + α)
                deltaPosition: toWad('-131.067')
            },
            {
                name: 'open 0 -> 100',
                amm: amm0,
                amount: toWad('100'),
                deltaCash: toWad('-4995'), // trader sell, -5000 (1 - α)
                deltaPosition: toWad('100')
            },
            {
                name: 'open 10 -> 100',
                amm: amm4,
                amount: toWad('90'),
                deltaCash: toWad('-4045.95'), // trader sell, -4050 (1 - α)
                deltaPosition: toWad('90')
            },
            {
                name: 'close -10 -> -9',
                amm: amm1,
                amount: toWad('1'),
                deltaCash: toWad('-108.4371405102481132569021'), // trader sell, -108.5456861964445578147169 (1 - α)
                deltaPosition: toWad('1')
            },
            {
                name: 'close -10 -> 0',
                amm: amm1,
                amount: toWad('10'),
                deltaCash: toWad('-1043.932318474990069773169'), // trader sell, -1044.977295770760830603773 (1 - α)
                deltaPosition: toWad('10')
            },
            {
                name: 'close 10 -> 9',
                amm: amm4,
                amount: toWad('-1'),
                deltaCash: toWad('91.5457681173589976274684'), // trader buy, 91.4543138035554421852831 (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'close 10 -> 0',
                amm: amm4,
                amount: toWad('-10'),
                deltaCash: toWad('955.977726933468408565623'), // trader buy, 955.022704229239169396227 (1 + α)
                deltaPosition: toWad('-10')
            },
            {
                name: 'close unsafe -10 -> -9',
                amm: amm3,
                amount: toWad('1'),
                deltaCash: toWad('-99.9'), // trader sell, 100 (1 - α),
                deltaPosition: toWad('1')
            },
            {
                name: 'close unsafe 10 -> 9',
                amm: amm6,
                amount: toWad('-1'),
                deltaCash: toWad('100.1'), // trader buy, 100 (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'close negative price, clip to 0',
                amm: amm7,
                amount: toWad('-0.01'),
                deltaCash: _0, // trader buy, 0 (1 + α)
                deltaPosition: toWad('-0.01')
            },
            {
                name: 'open 0 -> -141.422, partialFill',
                amm: amm0,
                amount: toWad('-141.422'),
                partialFill: true,
                deltaCash: toWad('24166.2777593546814385049041293'), // trader buy, 24142.1356237309504880168872421 (1 + α)
                deltaPosition: toWad('-141.421356237309504880168872421')
            },
            {
                name: 'open -10 -> -141.068, pos2 too large, partialFill',
                amm: amm1,
                amount: toWad('-131.068'),
                partialFill: true,
                deltaCash: toWad('23029.7427156455503096573958546'), // trader buy, 23006.7359796658844252321636909 (1 + α)
                deltaPosition: toWad('-131.067359796658844252321636909')
            },
            {
                name: 'open -10 already unsafe, partialFill',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: true,
                deltaCash: _0,
                deltaPosition: _0
            },
            {
                name: 'open 0 -> 100.001, partialFill',
                amm: amm0,
                amount: toWad('100.001'),
                partialFill: true,
                deltaCash: toWad('-4995'), // trader sell, -5000 (1 - α)
                deltaPosition: toWad('100')
            },
            {
                name: 'open 10 -> 100.001, partialFill',
                amm: amm4,
                amount: toWad('90.001'),
                partialFill: true,
                deltaCash: toWad('-4045.95'), // trader sell, -4050 (1 - α)
                deltaPosition: toWad('90')
            },
            {
                name: 'open 10 already unsafe, partialFill',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: true,
                deltaCash: _0,
                deltaPosition: _0
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                const context = await amm.queryTradeWithAMM(element.amount, element.partialFill)
                expect(context[0]).approximateBigNumber(element.deltaCash)
                expect(context[1]).approximateBigNumber(element.deltaPosition)
            })
        })
    })

    describe('trade - fail', function () {

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
                await amm.setParams(params.unitAccumulativeFunding, params.halfSpread, params.openSlippageFactor, params.closeSlippageFactor, params.ammMaxLeverage, element.amm.cash, element.amm.positionAmount1, element.amm.positionAmount2, params.indexPrice, params.indexPrice)
                await expect(amm.queryTradeWithAMM(element.amount, element.partialFill)).to.be.revertedWith(element.errorMsg)
            })
        })
    })
});
