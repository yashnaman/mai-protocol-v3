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
                deltaMargin: toWad('3003'), // trader buy, (1 + α)
                deltaPosition: toWad('-25'),
                partialFill: false
            },
            {
                name: 'open -11 -> -24',
                amm: amm1,
                amount: toWad('-13'),
                deltaMargin: toWad('1710.761468483122593073'), // trader buy, (1 + α)
                deltaPosition: toWad('-13'),
                partialFill: false
            },
            {
                name: 'open 0 -> 37',
                amm: amm0,
                amount: toWad('37'),
                deltaMargin: toWad('-2896.60792953216181'), // trader sell, (1 - α)
                deltaPosition: toWad('37'),
                partialFill: false
            },
            {
                name: 'open 11 -> 36',
                amm: amm4,
                amount: toWad('25'),
                deltaMargin: toWad('-1775.58545802588185'), // trader sell, (1 - α)
                deltaPosition: toWad('25'),
                partialFill: false
            },
            {
                name: 'close -11 -> -10',
                amm: amm1,
                amount: toWad('1'),
                deltaMargin: toWad('-105.919615384615385'), // trader sell, (1 - α)
                deltaPosition: toWad('1'),
                partialFill: false
            },
            {
                name: 'close -11 -> 0',
                amm: amm1,
                amount: toWad('11'),
                deltaMargin: toWad('-1129.89461538461538'), // trader sell, (1 - α)
                deltaPosition: toWad('11'),
                partialFill: false
            },
            {
                name: 'close 11 -> 10',
                amm: amm4,
                amount: toWad('-1'),
                deltaMargin: toWad('94.6008831068813075'), // trader buy, (1 + α)
                deltaPosition: toWad('-1'),
                partialFill: false
            },
            {
                name: 'close 11 -> 0',
                amm: amm4,
                amount: toWad('-11'),
                deltaMargin: toWad('1071.88792321443440'), // trader buy, (1 + α)
                deltaPosition: toWad('-11'),
                partialFill: false
            },
            {
                name: 'close unsafe -11 -> -10',
                amm: amm3,
                amount: toWad('1'),
                deltaMargin: toWad('-99.9'), // trader sell, (1 - α)
                deltaPosition: toWad('1'),
                partialFill: false
            },
            {
                name: 'close unsafe 11 -> 10',
                amm: amm6,
                amount: toWad('-1'),
                deltaMargin: toWad('100.1'), // trader buy, (1 + α)
                deltaPosition: toWad('-1'),
                partialFill: false
            },
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
                name: 'open 0 -> -25.01, pos2 too large',
                amm: amm0,
                amount: toWad('-25.01'),
                partialFill: false,
                errorMsg: 'Trade amount exceeds max amount'
            },
            {
                name: 'open -11 -> -24.2, pos2 too large',
                amm: amm1,
                amount: toWad('-13.2'),
                partialFill: false,
                errorMsg: 'Trade amount exceeds max amount'
            },
            {
                name: 'open -11 already unsafe',
                amm: amm3,
                amount: toWad('-0.01'),
                partialFill: false,
                errorMsg: 'Unsafe before open position'
            },
            {
                name: 'open 0 -> 37.3',
                amm: amm0,
                amount: toWad('37.3'),
                partialFill: false,
                errorMsg: 'Trade amount exceeds max amount'
            },
            {
                name: 'open 11 -> 36.3',
                amm: amm4,
                amount: toWad('25.3'),
                partialFill: false,
                errorMsg: 'Trade amount exceeds max amount'
            },
            {
                name: 'open 11 already unsafe',
                amm: amm6,
                amount: toWad('0.01'),
                partialFill: false,
                errorMsg: 'Unsafe before open position'
            },
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
                name: 'initial state',
                amm: ammInit,
                totalShare: _0,
                marginToAdd: toWad('1000'),
                unitAccumulatedFundingLoss: _0,
                share: toWad('5000')
            },
            {
                name: 'before safe, after safe',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                unitAccumulatedFundingLoss: params.unitAccumulatedFundingLoss,
                share: toWad('107.408041859396039759')
            },
            {
                name: 'before unsafe, after safe',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                unitAccumulatedFundingLoss: params.unitAccumulatedFundingLoss,
                share: toWad('107.408041859396039759')
            },
            /*
            {
                name: 'before unsafe, after safe',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                unitAccumulatedFundingLoss: params.unitAccumulatedFundingLoss,
                share: toWad('107.408041859396039759')
            },
            {
                name: 'old m0 = 0',
                amm: amm1,
                totalShare: toWad('100'),
                marginToAdd: toWad('1000'),
                unitAccumulatedFundingLoss: params.unitAccumulatedFundingLoss,
                share: toWad('107.408041859396039759')
            }
            */
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(element.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                expect(await AMM.addLiquidity(element.totalShare, element.marginToAdd)).approximateBigNumber(element.share)
            })
        })

        const failCases = []
    })

    describe('remove liquidity', function () {
        const cases = [
            {
                name: 'normal',
                amm: amm1,
                totalShare: toWad('100'),
                shareToRemove: toWad('10'),
                marginToRemove: toWad('86.96765668805676924')
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await AMM.setParams(params.unitAccumulatedFundingLoss, params.halfSpreadRate, params.beta1, params.beta2, params.targetLeverage, element.amm.cashBalance, element.amm.positionAmount, element.amm.entryFundingLoss, toWad('100'))
                expect(await AMM.removeLiquidity(element.totalShare, element.shareToRemove)).approximateBigNumber(element.marginToRemove)
            })
        })
    })
});
