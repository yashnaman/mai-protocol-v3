import BigNumber from 'bignumber.js'
import { ethers } from "hardhat";
import { waffleChai } from "@ethereum-waffle/chai";
import { expect, use } from "chai";

import "./helper";

use(waffleChai);

const weis = new BigNumber('1000000000000000000');
const toWad = (x: any) => {
  return new BigNumber(x).times(weis).toFixed(0);
}
const _0 = toWad('0')

const params = {
  unitAccumulatedFundingLoss: toWad('1.9'),
  halfSpreadRate: toWad('0.001'),
  beta1: toWad('0.2'),
  beta2: toWad('0.1'),
  targetLeverage: toWad('5')
}

// empty
const ammInit = {
    cashBalance: _0,
    positionAmount: _0,
    entryFundingLoss: _0,
}

// empty
const amm0 = {
    cashBalance: toWad('1000'),
    positionAmount: _0,
    entryFundingLoss: _0,
}

// short 1: normal
const amm1 = {
    cashBalance: toWad('2109.21564102564103'),
    positionAmount: toWad('-11'),
    entryFundingLoss: toWad('0.91'),
    // fundingLoss = 1.9 * (-11) - 0.91 = -21.81
    // available cash = 2109.21564102564103 - (-21.81) = 2131.02564102564103
}

// short 2: loss but safe
const amm2 = {
    cashBalance: toWad('1819.492395209580838'),
    positionAmount: toWad('-11'),
    entryFundingLoss: toWad('0.91'),
    // fundingLoss = 1.9 * (-11) - 0.91 = -21.81
    // available cash = 1819.492395209580838 - (-21.81) = 1841.302395209580838
}

// short 3: unsafe
const amm3 = {
    cashBalance: toWad('1534.987752808988764'),
    positionAmount: toWad('-11'),
    entryFundingLoss: toWad('0.91'),
    // fundingLoss = 1.9 * (-11) - 0.91 = -21.81
    // available cash = 1534.987752808988764 - (-21.81) = 1556.797752808988764
}

// long 1: normal
const amm4 = {
    cashBalance: toWad('-49.007106108326075085'),
    positionAmount: toWad('11'),
    entryFundingLoss: toWad('-0.91'),
    // funding = 1.9 * 11 -(-0.91) = 21.81
    // available cash = -49.007106108326075085 - 21.81 = -70.817106108326075085
}

// long 2: loss but safe
const amm5 = {
    cashBalance: toWad('-355.79900789632941'),
    positionAmount: toWad('11'),
    entryFundingLoss: toWad('-0.91'),
    // funding = 1.9 * 11 -(-0.91) = 21.81
    // available cash = -355.79900789632941 - 21.81 = -377.60900789632941
}

// long 3: unsafe
const amm6 = {
    cashBalance: toWad('-653.74080722289376'),
    positionAmount: toWad('11'),
    entryFundingLoss: toWad('-0.91'),
    // funding = 1.9 * 11 -(-0.91) = 21.81
    // available cash = -653.74080722289376 - 21.81 = -675.55080722289376
}

describe('AMM', () => {
    let AMM;

    let createFromFactory = async (path, libraries = {}) => {
        const factory = await ethers.getContractFactory(path, { libraries: libraries });
        const deployed = await factory.deploy();
        return deployed;
    }

    beforeEach(async () => {
        const AMMTradeModule = await createFromFactory("contracts/module/AMMTradeModule.sol:AMMTradeModule")
        AMM = await createFromFactory("contracts/test/TestAMM.sol:TestAMM", {AMMTradeModule: AMMTradeModule.address});
    });

    describe('isAMMSafe', function () {

        const cases = [
            {
                name: 'zero position is always safe',
                cashBalance: _0,
                positionAmount: _0,
                indexPrice: toWad('11.026192936488206'),
                isSafe: true
            },
            {
                name: 'long - non-negative cash is always safe',
                cashBalance: _0,
                positionAmount: toWad('11'),
                indexPrice: _0,
                isSafe: true
            },
            {
                name: 'long - ok',
                cashBalance: toWad('-70.81710610832608'),
                positionAmount: toWad('11'),
                indexPrice: toWad('11.026192936488206'),
                isSafe: true
            },
            {
                name: 'long - fail',
                cashBalance: toWad('-70.81710610832608'),
                positionAmount: toWad('11'),
                indexPrice: toWad('11.026192936488204'),
                isSafe: false
            },
            {
                name: 'short - ok',
                cashBalance: toWad('2131.0256410256410'),
                positionAmount: toWad('-11'),
                indexPrice: toWad('130.647439610301681'),
                isSafe: true
            },
            {
                name: 'short - fail',
                cashBalance: toWad('2131.0256410256410'),
                positionAmount: toWad('-11'),
                indexPrice: toWad('130.647439610301682'),
                isSafe: false
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(_0, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.cashBalance, element.positionAmount, _0, element.indexPrice)
                if (element.isSafe) {
                    expect(await AMM.isAMMMarginSafe(toWad('0.1') /* beta */)).to.be.true
                } else {
                    expect(await AMM.isAMMMarginSafe(toWad('0.1') /* beta */)).to.be.false
                }
            })
        })
    })

    describe('regress', function () {

        const successCases = [
            {
                amm: amm0,
                mv: toWad('4000'),
                m0: toWad('5000'),
            },
            {
                amm: amm1,
                mv: toWad('4000'),
                m0: toWad('5000'),
            },
            {
                amm: amm2,
                mv: toWad('2759.160077895718149991'),
                m0: toWad('3448.950097369647687489'),
            },
            {
                amm: amm4,
                mv: toWad('4000'),
                m0: toWad('5000'),
            },
            {
                amm: amm5,
                mv: toWad('2698.739297452669114401'),
                m0: toWad('3373.424121815836393002'),
            }
        ]

        successCases.forEach((element, index) => {
            it(`success-${index}`, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                const context = await AMM.regress(toWad('0.1') /* beta */)
                expect(context.mv).approximateBigNumber(element.mv)
                expect(context.m0).approximateBigNumber(element.m0)
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
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                await expect(AMM.regress(toWad('0.1') /* beta */)).to.be.revertedWith('amm is unsafe when regress')
            })
        })
    })

    describe('virtualM0', function () {

        const successCases = [
            {
                name: 'short ok',
                amm: amm3,
                virtualM0: toWad('1691.99438202247191')
            },
            {
                name: 'long ok',
                amm: amm6,
                virtualM0: toWad('1251.861461572715009523')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                expect(await AMM.virtualM0()).approximateBigNumber(element.virtualM0)
            })
        })

        const failCases = [
            {
                name: 'short fail',
                cashBalance: toWad('879'),
                positionAmount: toWad('-11'),
                errorMsg: 'short virtual m0 is not position'
            },
            {
                name: 'long fail',
                cashBalance: toWad('-1295'),
                positionAmount: toWad('11'),
                errorMsg: 'long virtual m0 is not position'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(_0, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.cashBalance, element.positionAmount, _0, toWad('100'))
                await expect(AMM.virtualM0()).to.be.revertedWith(element.errorMsg)
            })
        })
    })


    describe('computeDeltaMargin', function () {

        const cases = [
            {
                name: '0 -> +5',
                amm: amm0,
                amount: toWad('5'),
                side: 'long',
                deltaMargin: toWad('-494.570984085309081')
            },
            {
                name: '0 -> -5',
                amm: amm0,
                amount: toWad('-5'),
                side: 'short',
                deltaMargin: toWad('505.555555555555556')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                if (element.side == 'long') {
                    expect(await AMM.longDeltaMargin(element.amount, toWad('0.1') /* beta */)).approximateBigNumber(element.deltaMargin)
                } else {
                    expect(await AMM.shortDeltaMargin(element.amount, toWad('0.1') /* beta */)).approximateBigNumber(element.deltaMargin)
                }
            })
        })

        const failCases = [
            {
                name: 'short m0 + ipos2 = 0',
                amm: amm0,
                amount: toWad('-50'),
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                await expect(AMM.shortDeltaMargin(element.amount, toWad('0.1') /* beta */)).to.be.revertedWith('short condition is not satisfied')
            })
        })
    })

    describe('safePosition', function () {
        const cases = [
            {
                name: 'short index = 0',
                amm: amm0,
                side: 'short',
                beta: toWad('0.2'),
                targetLeverage: toWad('5'),
                indexPrice: _0,
                maxPosition: toWad('-57896044618658097711785492504343953926634992332820282019728.792003956564819968') /* min int256 */
            },
            {
                name: 'long index = 0',
                amm: amm0,
                side: 'long',
                beta: toWad('0.2'),
                targetLeverage: toWad('5'),
                indexPrice: _0,
                maxPosition: toWad('57896044618658097711785492504343953926634992332820282019728.792003956564819968') /* max int256 */
            },
            {
                name: 'short from 0',
                amm: amm0,
                side: 'short',
                beta: toWad('0.2'),
                targetLeverage: toWad('5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('-25')
            },
            {
                name: 'long from 0',
                amm: amm0,
                side: 'long',
                beta: toWad('0.2'),
                targetLeverage: toWad('5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('37.2594670356232003')
            },
            {
                name: 'short: √  (beta lev) < 1',
                amm: amm0,
                side: 'short',
                beta: toWad('0.1'),
                targetLeverage: toWad('5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('-29.28932188134524756')
            },
            {
                name: 'short: √  (beta lev) = 1',
                amm: amm0,
                side: 'short',
                beta: toWad('0.2'),
                targetLeverage: toWad('5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('-25')
            },
            {
                name: 'short: √  (beta lev) > 1',
                amm: amm0,
                side: 'short',
                beta: toWad('0.99'),
                targetLeverage: toWad('5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('-15.50455121681897322')
            },
            {
                name: 'long: (-1 + beta + beta lev) = 0, implies beta < 0.5',
                amm: amm4,
                side: 'long',
                beta: toWad('0.2'),
                targetLeverage: toWad('4'),
                indexPrice: toWad('100'),
                maxPosition: toWad('31.7977502570247453')
            },
            {
                name: 'long: (-1 + beta + beta lev) < 0 && lev < 2 && beta < (2 - lev)/2',
                amm: amm4,
                side: 'long',
                beta: toWad('0.1'),
                targetLeverage: toWad('1.5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('17.689313632528408')
            },
            {
                name: 'long: (-1 + beta + beta lev) < 0 && beta >= (2 - lev)/2',
                amm: amm4,
                side: 'long',
                beta: toWad('0.3'),
                targetLeverage: toWad('1.5'),
                indexPrice: toWad('100'),
                maxPosition: toWad('15.875912065096235')
            },
            {
                name: 'long: (-1 + beta + beta lev) < 0 && lev >= 2',
                amm: amm4,
                side: 'long',
                beta: toWad('0.1'),
                targetLeverage: toWad('2'),
                indexPrice: toWad('100'),
                maxPosition: toWad('21.2517072860587530')
            },
            {
                name: 'long: (-1 + beta + beta lev) > 0',
                amm: amm4,
                side: 'long',
                beta: toWad('0.99'),
                targetLeverage: toWad('2'),
                indexPrice: toWad('100'),
                maxPosition: toWad('18.2026549289986863')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, element.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, element.indexPrice)
                if (element.side == 'long') {
                    expect(await AMM.maxLongPosition(element.beta)).approximateBigNumber(element.maxPosition)
                } else {
                    expect(await AMM.maxShortPosition(element.beta)).approximateBigNumber(element.maxPosition)
                }
            })
        })
    })

    describe('trade - success', function () {

        const successCases = [
            {
                name: 'open 0 -> -25',
                amm: amm0,
                amount: toWad('-25'),
                partialFill: false,
                deltaMargin: toWad('3003'), // trader buy, (1 + α)
                deltaPosition: toWad('-25')
            },
            {
                name: 'open -11 -> -24',
                amm: amm1,
                amount: toWad('-13'),
                partialFill: false,
                deltaMargin: toWad('1710.761468483122593073'), // trader buy, (1 + α)
                deltaPosition: toWad('-13')
            },
            {
                name: 'open 0 -> 37',
                amm: amm0,
                amount: toWad('37'),
                partialFill: false,
                deltaMargin: toWad('-2896.60792953216181'), // trader sell, (1 - α)
                deltaPosition: toWad('37')
            },
            {
                name: 'open 11 -> 36',
                amm: amm4,
                amount: toWad('25'),
                partialFill: false,
                deltaMargin: toWad('-1775.58545802588185'), // trader sell, (1 - α)
                deltaPosition: toWad('25')
            },
            {
                name: 'close -11 -> -10',
                amm: amm1,
                amount: toWad('1'),
                partialFill: false,
                deltaMargin: toWad('-105.919615384615385'), // trader sell, (1 - α)
                deltaPosition: toWad('1')
            },
            {
                name: 'close -11 -> 0',
                amm: amm1,
                amount: toWad('11'),
                partialFill: false,
                deltaMargin: toWad('-1129.89461538461538'), // trader sell, (1 - α)
                deltaPosition: toWad('11')
            },
            {
                name: 'close 11 -> 10',
                amm: amm4,
                amount: toWad('-1'),
                partialFill: false,
                deltaMargin: toWad('94.6008831068813075'), // trader buy, (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'close 11 -> 0',
                amm: amm4,
                amount: toWad('-11'),
                partialFill: false,
                deltaMargin: toWad('1071.88792321443440'), // trader buy, (1 + α)
                deltaPosition: toWad('-11')
            },
            {
                name: 'close unsafe -11 -> -10',
                amm: amm3,
                amount: toWad('1'),
                partialFill: false,
                deltaMargin: toWad('-99.9'), // trader sell, (1 - α)
                deltaPosition: toWad('1')
            },
            {
                name: 'close unsafe 11 -> 10',
                amm: amm6,
                amount: toWad('-1'),
                partialFill: false,
                deltaMargin: toWad('100.1'), // trader buy, (1 + α)
                deltaPosition: toWad('-1')
            },
            {
                name: 'open 0 -> -25.01, partialFill',
                amm: amm0,
                amount: toWad('-25.01'),
                partialFill: true,
                deltaMargin: toWad('3003'),
                deltaPosition: toWad('-25')
            },
            {
                name: 'open -11 -> -24.2, partialFill',
                amm: amm1,
                amount: toWad('-13.2'),
                partialFill: true,
                deltaMargin: toWad('1735.348835541285897908'),
                deltaPosition: toWad('-13.154005383416287268')
            },
            {
                name: 'open -11 already unsafe, partialFill',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: true,
                deltaMargin: _0,
                deltaPosition: _0
            },
            {
                name: 'open 0 -> 37.3, partialFill',
                amm: amm0,
                amount: toWad('37.3'),
                partialFill: true,
                deltaMargin: toWad('-2909.965596304420832907'),
                deltaPosition: toWad('37.259467035623200279')
            },
            {
                name: 'open 11 -> 36.3, partialFill',
                amm: amm4,
                amount: toWad('25.3'),
                partialFill: true,
                deltaMargin: toWad('-1787.086250639889059394'),
                deltaPosition: toWad('25.223493715622091689')
            },
            {
                name: 'open 11 already unsafe, partialFill',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: true,
                deltaMargin: _0,
                deltaPosition: _0
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                const context = await AMM.tradeWithAMM(element.amount, element.partialFill)
                expect(context.deltaMargin).approximateBigNumber(element.deltaMargin)
                expect(context.deltaPosition).approximateBigNumber(element.deltaPosition)
            })
        })
    })

    describe('trade - fail', function () {

        const failCases = [
            {
                name: 'zero trade amount',
                amm: amm0,
                amount: _0,
                partialFill: false,
                errorMsg: 'trade amount is zero'
            },
            {
                name: 'open 0 -> -25.01, pos2 too large',
                amm: amm0,
                amount: toWad('-25.01'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open -11 -> -24.2, pos2 too large',
                amm: amm1,
                amount: toWad('-13.2'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open -11 already unsafe',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: false,
                errorMsg: 'amm is unsafe when open'
            },
            {
                name: 'open 0 -> 37.3',
                amm: amm0,
                amount: toWad('37.3'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open 11 -> 36.3',
                amm: amm4,
                amount: toWad('25.3'),
                partialFill: false,
                errorMsg: 'trade amount exceeds max amount'
            },
            {
                name: 'open 11 already unsafe',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: false,
                errorMsg: 'amm is unsafe when open'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                await expect(AMM.tradeWithAMM(element.amount, element.partialFill)).to.be.revertedWith(element.errorMsg)
            })
        })
    })

    describe('add liquidity', function () {

        const successCases = [
            {
                name: 'initial state(old m0 = 0)',
                amm: ammInit,
                totalShare: _0,
                marginToAdd: toWad('1000'),
                share: toWad('5000')
            },
            {
                name: 'before safe, after safe',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                share: toWad('107.408041859396039759')
            },
            {
                name: 'short, before unsafe, after unsafe',
                amm: amm3,
                totalShare: toWad('100'),
                marginToAdd: toWad('203'),
                share: toWad('29.994189424753050553')
            },
            {
                name: 'short, before unsafe, after safe',
                amm: amm3,
                totalShare: toWad('100'),
                marginToAdd: toWad('204'),
                share: toWad('34.058581410041613024')
            },
            {
                name: 'long, before unsafe, after unsafe',
                amm: amm6,
                totalShare: toWad('100'),
                marginToAdd: toWad('110'),
                share: toWad('17.783041850283580957')
            },
            {
                name: 'long, before unsafe, after safe',
                amm: amm6,
                totalShare: toWad('100'),
                marginToAdd: toWad('111'),
                share: toWad('20.829626062945364605')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                expect(await AMM.addLiquidity(element.totalShare, element.marginToAdd)).approximateBigNumber(element.share)
            })
        })

        const failCases = [
            {
                name: 'invalid margin to add',
                totalShare: toWad('100'),
                marginToAdd: _0,
                errorMsg: 'margin to add must be positive'
            },
            {
                name: 'm0 = 0 && totalShare != 0',
                totalShare: toWad('100'),
                marginToAdd: toWad('100'),
                errorMsg: 'share has no value'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(_0, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, ammInit.cashBalance, ammInit.positionAmount, _0, toWad('100'))
                await expect(AMM.addLiquidity(element.totalShare, element.marginToAdd)).to.be.revertedWith(element.errorMsg)
            })
        })

    })

    describe('remove liquidity', function () {

        const successCases = [
            {
                name: 'no position',
                amm: amm0,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                marginToRemove: toWad('100')
            },
            {
                name: 'short',
                amm: amm1,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                marginToRemove: toWad('86.967656688056717601')
            },
            {
                name: 'long',
                amm: amm4,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                marginToRemove: toWad('89.952448465310273482')
            }
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                expect(await AMM.removeLiquidity(element.totalShare, element.shareToRemove)).approximateBigNumber(element.marginToRemove)
            })
        })

        const failCases = [
            {
                name: 'invalid share',
                amm: amm0,
                totalShare: _0,
                shareToRemove: toWad('10'),
                errorMsg: 'invalid share when remove liquidity',
            },
            {
                name: 'invalid share',
                amm: amm0,
                totalShare: toWad('100'),
                shareToRemove: _0,
                errorMsg: 'invalid share when remove liquidity',
            },
            {
                name: 'invalid share',
                amm: amm0,
                totalShare: toWad('100'),
                shareToRemove: toWad('100.1'),
                errorMsg: 'invalid share when remove liquidity',
            },
            {
                name: 'short, before unsafe',
                amm: amm3,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                errorMsg: 'amm is unsafe before remove liquidity',
            },
            {
                name: 'long, before unsafe',
                amm: amm6,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                errorMsg: 'amm is unsafe before remove liquidity',
            },
            {
                name: 'short, after unsafe',
                amm: amm1,
                totalShare: toWad('100'),
                shareToRemove: toWad('54.459'),
                errorMsg: 'amm is unsafe after remove liquidity',
            },
            {
                name: 'long, after unsafe',
                amm: amm4,
                totalShare: toWad('100'),
                shareToRemove: toWad('69.633'),
                errorMsg: 'amm is unsafe after remove liquidity',
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                await expect(AMM.removeLiquidity(element.totalShare, element.shareToRemove)).to.be.revertedWith(element.errorMsg)
            })
        })

    })
});
