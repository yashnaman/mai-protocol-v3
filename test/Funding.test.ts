import BigNumber from 'bignumber.js';
import { expect } from "chai";
import { toWei } from "../scripts/utils"

import "./helper";
import {
    createContract,
} from '../scripts/utils';

const _0 = toWei('0')

const params = {
    state: 2,
    unitAccumulativeFunding: toWei('1.9'),
    openSlippageFactor: toWei('1'),
    ammMaxLeverage: toWei('5'),
    maxClosePriceDiscount: toWei('0.05'),
    indexPrice: toWei('100'),
    fundingRateLimit: toWei('0.005'),
    negFundingRateLimit: toWei('-0.005')
}

describe('Funding', () => {
    let oracle1;
    let oracle2;
    let perpetual;

    beforeEach(async () => {
        const AMMModule = await createContract("AMMModule");
        const CollateralModule = await createContract("CollateralModule")
        const OrderModule = await createContract("OrderModule");
        const PerpetualModule = await createContract("PerpetualModule");
        const SignatureModule = await createContract("SignatureModule");
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule, SignatureModule });
        const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
        perpetual = await createContract("TestPerpetual", [], {
            PerpetualModule,
            LiquidityPoolModule,
            TradeModule,
            SignatureModule,
        });
        oracle1 = await createContract("OracleWrapper", ["USD", "ETH"]);
        oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
    });

    describe('updateFundingState', function () {

        const cases = [
            {
                name: 'state != NORMAL',
                state: 1,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWei('100'),
                indexPrice2: toWei('200'),
                fundingRate: toWei('0.002'),
                timeElapsed: '1000',
                targetUnitAccumulativeFunding1: params.unitAccumulativeFunding,
                targetUnitAccumulativeFunding2: params.unitAccumulativeFunding,
                targetFundingTime: '1000'
            },
            {
                name: 'init',
                state: params.state,
                unitAccumulativeFunding: _0,
                indexPrice1: toWei('100'),
                indexPrice2: toWei('200'),
                fundingRate: toWei('0'),
                timeElapsed: '1000',
                targetUnitAccumulativeFunding1: _0,
                targetUnitAccumulativeFunding2: _0,
                targetFundingTime: '1000'
            },
            {
                name: 'current time = perpetual time',
                state: params.state,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWei('100'),
                indexPrice2: toWei('200'),
                fundingRate: toWei('0.002'),
                timeElapsed: '0',
                targetUnitAccumulativeFunding1: params.unitAccumulativeFunding,
                targetUnitAccumulativeFunding2: params.unitAccumulativeFunding,
                targetFundingTime: '1000'
            },
            {
                name: 'normal',
                state: params.state,
                unitAccumulativeFunding: params.unitAccumulativeFunding,
                indexPrice1: toWei('100'),
                indexPrice2: toWei('200'),
                fundingRate: toWei('0.002'),
                timeElapsed: '1000',
                targetUnitAccumulativeFunding1: toWei('1.906944444444444444'),
                targetUnitAccumulativeFunding2: toWei('1.913888888888888888'),
                targetFundingTime: '2000'
            }
        ]

        cases.forEach(element => {
            it(element.name, async () => {

                await perpetual.createPerpetual(
                    oracle1.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.createPerpetual(
                    oracle2.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.setMarginAccount(0, perpetual.address, 0, 0);
                await perpetual.setIndexPrice(0, element.indexPrice1);
                await perpetual.setFundingRate(0, element.fundingRate);
                await perpetual.setUnitAccumulativeFunding(0, element.unitAccumulativeFunding);
                await perpetual.setState(0, element.state);

                await perpetual.setMarginAccount(1, perpetual.address, 0, 0);
                await perpetual.setIndexPrice(1, element.indexPrice2);
                await perpetual.setFundingRate(1, element.fundingRate);
                await perpetual.setUnitAccumulativeFunding(1, element.unitAccumulativeFunding);
                await perpetual.setState(1, element.state);

                await perpetual.setPoolCash(0);

                expect(await perpetual.callStatic.updateFundingState(0, element.timeElapsed)).approximateBigNumber(element.targetUnitAccumulativeFunding1)
                expect(await perpetual.callStatic.updateFundingState(1, element.timeElapsed)).approximateBigNumber(element.targetUnitAccumulativeFunding2)
            })
        })
    })

    describe('updateFundingRate', function () {

        const successCases = [
            {
                name: 'state != NORMAL',
                state: 1,
                cash: toWei('10100'),
                positionAmount1: toWei('-10'),
                positionAmount2: toWei('10'),
                targetFundingRate1: _0,
                targetFundingRate2: _0
            },
            {
                name: 'init',
                state: params.state,
                cash: _0,
                positionAmount1: _0,
                positionAmount2: _0,
                targetFundingRate1: _0,
                targetFundingRate2: _0
            },
            {
                name: 'unsafe',
                state: params.state,
                cash: toWei('17692'),
                positionAmount1: toWei('-80'),
                positionAmount2: toWei('10'),
                targetFundingRate1: params.fundingRateLimit,
                targetFundingRate2: params.negFundingRateLimit
            },
            {
                name: 'normal',
                state: params.state,
                cash: toWei('10100'),
                positionAmount1: toWei('-10'),
                positionAmount2: toWei('10'),
                targetFundingRate1: toWei('0.0005'),
                targetFundingRate2: toWei('-0.0005')
            },
            {
                name: 'exceed limit',
                state: params.state,
                cash: toWei('10099'),
                positionAmount1: toWei('60'),
                positionAmount2: toWei('-50'),
                targetFundingRate1: toWei('-0.005'),
                targetFundingRate2: toWei('0.004182195596258372')
            },
        ]

        successCases.forEach(element => {
            it(element.name, async () => {
                await perpetual.createPerpetual(
                    oracle1.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.createPerpetual(
                    oracle2.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.setMarginAccount(0, perpetual.address, 0, element.positionAmount1);
                await perpetual.setIndexPrice(0, params.indexPrice);
                await perpetual.setFundingRate(0, 0);
                await perpetual.setUnitAccumulativeFunding(0, params.unitAccumulativeFunding);
                await perpetual.setState(0, element.state);

                await perpetual.setMarginAccount(1, perpetual.address, 0, element.positionAmount2);
                await perpetual.setIndexPrice(1, params.indexPrice);
                await perpetual.setFundingRate(1, 0);
                await perpetual.setUnitAccumulativeFunding(1, params.unitAccumulativeFunding);
                await perpetual.setState(1, element.state);

                await perpetual.setPoolCash(element.cash);

                expect(await perpetual.callStatic.updateFundingRate(0)).approximateBigNumber(element.targetFundingRate1)
                expect(await perpetual.callStatic.updateFundingRate(1)).approximateBigNumber(element.targetFundingRate2)
            })
        })

        const failCases = [
            {
                name: 'margin balance < 0',
                cash: toWei('10000'),
                positionAmount1: toWei('-50'),
                positionAmount2: toWei('-52'),
                errorMsg: 'amm is emergency'
            }
        ]

        failCases.forEach(element => {
            it(element.name, async () => {

                await perpetual.createPerpetual(
                    oracle1.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.createPerpetual(
                    oracle2.address,
                    [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
                    [toWei("0.01"), params.openSlippageFactor, params.openSlippageFactor, params.fundingRateLimit, params.ammMaxLeverage, params.maxClosePriceDiscount],
                )
                await perpetual.setMarginAccount(0, perpetual.address, 0, element.positionAmount1);
                await perpetual.setIndexPrice(0, params.indexPrice);
                await perpetual.setFundingRate(0, 0);
                await perpetual.setUnitAccumulativeFunding(0, params.unitAccumulativeFunding);
                await perpetual.setState(0, params.state);

                await perpetual.setMarginAccount(1, perpetual.address, 0, element.positionAmount2);
                await perpetual.setIndexPrice(1, params.indexPrice);
                await perpetual.setFundingRate(1, 0);
                await perpetual.setUnitAccumulativeFunding(1, params.unitAccumulativeFunding);
                await perpetual.setState(1, params.state);

                await perpetual.setPoolCash(element.cash);

                await expect(perpetual.callStatic.updateFundingRate(0)).to.be.revertedWith(element.errorMsg)
            })
        })
    })

})

