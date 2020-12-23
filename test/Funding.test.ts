import BigNumber from 'bignumber.js';
import { expect } from "chai";

import "./helper";
import {
    createContract,
} from '../scripts/utils';

const weis = new BigNumber('1000000000000000000');
const toWad = (x: any) => {
    return new BigNumber(x).times(weis).toFixed(0);
}
const _0 = toWad('0')

const params = {
    state: 2,
    unitAccumulativeFunding: toWad('1.9'),
    openSlippageFactor: toWad('100'),
    ammMaxLeverage: toWad('5'),
    indexPrice: toWad('100'),
    fundingRateLimit: toWad('0.005'),
    negFundingRateLimit: toWad('-0.005')
}

getDescription('Funding', () => {
    let funding;

    beforeEach(async () => {
        const collateralModule = await createContract("CollateralModule")
        const ammModule = await createContract("AMMModule", [], { "CollateralModule": collateralModule })
        const fundingModule = await createContract("FundingModule", [], { "AMMModule": ammModule });
        funding = await createContract("TestFunding", [], { "FundingModule": fundingModule });
    });

    getDescription('updateFundingState', function () {

        const cases = [
            {
                name: 'state != NORMAL',
                state: 1,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWad('100'),
                indexPrice2: toWad('200'),
                fundingRate: toWad('0.002'),
                fundingTime: '1000',
                currentTime: '2000',
                targetUnitAccumulativeFunding1: params.unitAccumulativeFunding,
                targetUnitAccumulativeFunding2: params.unitAccumulativeFunding,
                targetFundingTime: '1000'
            },
            {
                name: 'init',
                state: params.state,
                unitAccumulativeFunding: _0,
                indexPrice1: toWad('100'),
                indexPrice2: toWad('200'),
                fundingRate: toWad('0'),
                fundingTime: '0',
                currentTime: '1000',
                targetUnitAccumulativeFunding1: _0,
                targetUnitAccumulativeFunding2: _0,
                targetFundingTime: '1000'
            },
            {
                name: 'current time = funding time',
                state: params.state,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWad('100'),
                indexPrice2: toWad('200'),
                fundingRate: toWad('0.002'),
                fundingTime: '1000',
                currentTime: '1000',
                targetUnitAccumulativeFunding1: params.unitAccumulativeFunding,
                targetUnitAccumulativeFunding2: params.unitAccumulativeFunding,
                targetFundingTime: '1000'
            },
            {
                name: 'normal',
                state: params.state,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWad('100'),
                indexPrice2: toWad('200'),
                fundingRate: toWad('0.002'),
                fundingTime: '1000',
                currentTime: '2000',
                targetUnitAccumulativeFunding1: toWad('1.906944444444444444444444444444'),
                targetUnitAccumulativeFunding2: toWad('1.913888888888888888888888888889'),
                targetFundingTime: '2000'
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {
                await funding.setParams({
                    state: element.state,
                    unitAccumulativeFunding: element.unitAccumulativeFunding,
                    openSlippageFactor: params.openSlippageFactor,
                    ammMaxLeverage: params.ammMaxLeverage,
                    fundingRateLimit: params.fundingRateLimit,
                    cashBalance: _0,
                    positionAmount1: _0,
                    positionAmount2: _0,
                    indexPrice1: element.indexPrice1,
                    indexPrice2: element.indexPrice2,
                    fundingRate: element.fundingRate,
                    fundingTime: element.fundingTime,
                    time: element.currentTime
                })
                const context = await funding.callStatic.updateFundingState()
                expect(context[0]).approximateBigNumber(element.targetUnitAccumulativeFunding1)
                expect(context[1]).approximateBigNumber(element.targetUnitAccumulativeFunding2)
                expect(context[2]).approximateBigNumber(element.targetFundingTime)
            })
        })
    })

    getDescription('updateFundingRate', function () {

        const successCases = [
            {
                name: 'state != NORMAL',
                state: 1,
                cashBalance: toWad('10100'),
                positionAmount1: toWad('-10'),
                positionAmount2: toWad('10'),
                targetFundingRate1: _0,
                targetFundingRate2: _0
            },
            {
                name: 'init',
                state: params.state,
                cashBalance: _0,
                positionAmount1: _0,
                positionAmount2: _0,
                targetFundingRate1: _0,
                targetFundingRate2: _0
            },
            {
                name: 'unsafe',
                state: params.state,
                cashBalance: toWad('17692'),
                positionAmount1: toWad('-80'),
                positionAmount2: toWad('10'),
                targetFundingRate1: params.fundingRateLimit,
                targetFundingRate2: params.negFundingRateLimit
            },
            {
                name: 'normal',
                state: params.state,
                cashBalance: toWad('10100'),
                positionAmount1: toWad('-10'),
                positionAmount2: toWad('10'),
                targetFundingRate1: toWad('0.0005'),
                targetFundingRate2: toWad('-0.0005')
            },
            {
                name: 'exceed limit',
                state: params.state,
                cashBalance: toWad('10099'),
                positionAmount1: toWad('60'),
                positionAmount2: toWad('-50'),
                targetFundingRate1: toWad('-0.005'),
                targetFundingRate2: toWad('0.00418219559625837230897958914519')
            },
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await funding.setParams({
                    state: element.state,
                    unitAccumulativeFunding: params.unitAccumulativeFunding,
                    openSlippageFactor: params.openSlippageFactor,
                    ammMaxLeverage: params.ammMaxLeverage,
                    fundingRateLimit: params.fundingRateLimit,
                    cashBalance: element.cashBalance,
                    positionAmount1: element.positionAmount1,
                    positionAmount2: element.positionAmount2,
                    indexPrice1: params.indexPrice,
                    indexPrice2: params.indexPrice,
                    fundingRate: _0,
                    fundingTime: _0,
                    time: _0
                })
                const context = await funding.callStatic.updateFundingRate()
                expect(context[0]).approximateBigNumber(element.targetFundingRate1)
                expect(context[1]).approximateBigNumber(element.targetFundingRate2)
            })
        })

        const failCases = [
            {
                name: 'margin balance < 0',
                cashBalance: toWad('10000'),
                positionAmount1: toWad('-50'),
                positionAmount2: toWad('-52'),
                errorMsg: 'amm is emergency'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {
                await funding.setParams({
                    state: params.state,
                    unitAccumulativeFunding: params.unitAccumulativeFunding,
                    openSlippageFactor: params.openSlippageFactor,
                    ammMaxLeverage: params.ammMaxLeverage,
                    fundingRateLimit: params.fundingRateLimit,
                    cashBalance: element.cashBalance,
                    positionAmount1: element.positionAmount1,
                    positionAmount2: element.positionAmount2,
                    indexPrice1: params.indexPrice,
                    indexPrice2: params.indexPrice,
                    fundingRate: _0,
                    fundingTime: _0,
                    time: _0
                })
                await expect(funding.callStatic.updateFundingRate()).to.be.revertedWith(element.errorMsg)
            })
        })

    })

})

