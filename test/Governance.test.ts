const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

describe('Governance', () => {
    let accounts;
    let user0;
    let user1;
    let governance;
    let TestGovernance;

    const coreParameters = {
        initialMarginRate: toWei("0.1"),
        maintenanceMarginRate: toWei("0.05"),
        liquidationPenaltyRate: toWei("0.005"),
        keeperGasReward: toWei("1"),
        lpFeeRate: toWei("0.0007"),
        operatorFeeRate: toWei("0.0001"),
        referralRebateRate: toWei("0"),
    }
    const riskParameters = {
        halfSpread: toWei("0.001"),
        openSlippageFactor: toWei("0.2"),
        closeSlippageFactor: toWei("0.1"),
        fundingRateLimit: toWei("0.005"),
        targetLeverage: toWei("5"),
        maxClosePriceDiscount: toWei("0.05"),
    }

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];

        const AMMModule = await createContract("AMMModule");
        const CollateralModule = await createContract("CollateralModule")
        const PerpetualModule = await createContract("PerpetualModule");
        const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });

        TestGovernance = await createFactory(
            "TestGovernance",
            { PerpetualModule, LiquidityPoolModule }
        );
    })

    beforeEach(async () => {
        governance = await TestGovernance.deploy();
        await governance.initializeParameters(
            "0x0000000000000000000000000000000000000000",
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.2")],
            [toWei("0.01"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.9"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
        )
    })

    it('setPerpetualBaseParameter', async () => {
        await governance.setGovernor(user0.address);
        expect(await governance.initialMarginRate(0)).to.equal(toWei("0.1"));

        await governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.01"),
            toWei("1"),
            toWei("0.2"),
            toWei("100"),
        ]);

        expect(await governance.initialMarginRate(0)).to.equal(toWei("0.05"));
        expect(await governance.maintenanceMarginRate(0)).to.equal(toWei("0.025"));
        expect(await governance.operatorFeeRate(0)).to.equal(toWei("0.002"));
        expect(await governance.lpFeeRate(0)).to.equal(toWei("0.002"));
        expect(await governance.referralRebateRate(0)).to.equal(toWei("0.5"));
        expect(await governance.liquidationPenaltyRate(0)).to.equal(toWei("0.01"));
        expect(await governance.keeperGasReward(0)).to.equal(toWei("1"));
        expect(await governance.insuranceFundRate(0)).to.equal(toWei("0.2"));
        expect(await governance.insuranceFundCap(0)).to.equal(toWei("100"));
    })

    it('setPerpetualBaseParameter - exception', async () => {
        await governance.setGovernor(user1.address);
        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.01"),
            toWei("1"),
            toWei("0.2"),
            toWei("100"),
        ])).to.be.revertedWith("only governor is allowed");

        await governance.setGovernor(user0.address);
        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.11"),
            toWei("0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("cannot increase initialMarginRate");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.051"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("cannot increase maintenanceMarginRate");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.04"),
            toWei("0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("maintenanceMarginRate > initialMarginRate");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0"),
            toWei("0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("initialMarginRate <= 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("-0.01"),
            toWei("0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("initialMarginRate <= 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("maintenanceMarginRate <= 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("-0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("maintenanceMarginRate <= 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("-0.01"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("operatorFeeRate < 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.011"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("operatorFeeRate > 1%");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.01"),
            toWei("-0.01"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("lpFeeRate < 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.01"),
            toWei("0.011"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
            toWei("0.5"),
            toWei("1000")
        ])).to.be.revertedWith("lpFeeRate > 1%");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("-0.01"),
            toWei("1"),
            toWei("0.2"),
            toWei("100"),
        ])).to.be.revertedWith("liquidationPenaltyRate < 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.026"),
            toWei("1"),
            toWei("0.2"),
            toWei("100"),
        ])).to.be.revertedWith("liquidationPenaltyRate > maintenanceMarginRate");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.01"),
            toWei("-1"),
            toWei("0.2"),
            toWei("100"),
        ])).to.be.revertedWith("keeperGasReward < 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.01"),
            toWei("1"),
            toWei("-0.2"),
            toWei("100"),
        ])).to.be.revertedWith("insuranceFundRate < 0");

        await expect(governance.setPerpetualBaseParameter(0, [
            toWei("0.05"),
            toWei("0.025"),
            toWei("0.002"),
            toWei("0.002"),
            toWei("0.5"),
            toWei("0.01"),
            toWei("1"),
            toWei("0.2"),
            toWei("-100"),
        ])).to.be.revertedWith("insuranceFundCap < 0");
    })

    it('updatePerpetualRiskParameter', async () => {
        await governance.setOperatorNoAuth(user0.address);
        await governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])
        expect(await governance.halfSpread(0)).to.equal(toWei("0.5"));
        expect(await governance.openSlippageFactor(0)).to.equal(toWei("0.6"));
        expect(await governance.closeSlippageFactor(0)).to.equal(toWei("0.45"));
        expect(await governance.fundingRateLimit(0)).to.equal(toWei("0.1"));
        expect(await governance.ammMaxLeverage(0)).to.equal(toWei("5"));
        expect(await governance.maxClosePriceDiscount(0)).to.equal(toWei("0.05"));
    })

    it('setPerpetualRiskParameter - exception', async () => {

        await governance.setOperatorNoAuth(user0.address);
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("-1"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("halfSpread < 0");
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("1"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("halfSpread >= 100%");

        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("-0.1"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("openSlippageFactor < 0");

        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("-0.1"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("closeSlippageFactor < 0");

        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.8"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("closeSlippageFactor > openSlippageFactor");

        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("-0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("fundingRateLimit < 0");
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("-5"),
            toWei("0.05")
        ])).to.be.revertedWith("ammMaxLeverage < 0");
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("-0.05")
        ])).to.be.revertedWith("maxClosePriceDiscount < 0");
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("1")
        ])).to.be.revertedWith("maxClosePriceDiscount >= 100%");
    })

    it('updatePerpetualRiskParameter', async () => {
        await governance.setOperatorNoAuth(user1.address);
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.5"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("operator is allowed");

        await governance.setOperatorNoAuth(user0.address);
        await governance.updatePerpetualRiskParameter(0, [
            toWei("0.1"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ]);
        await governance.updatePerpetualRiskParameter(0, [
            toWei("0.9"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ]);

        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.99"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("value out fo range");
        await expect(governance.updatePerpetualRiskParameter(0, [
            toWei("0.001"),
            toWei("0.6"),
            toWei("0.45"),
            toWei("0.1"),
            toWei("5"),
            toWei("0.05")
        ])).to.be.revertedWith("value out fo range");
    })

    it("setLiquidityPoolParameter", async () => {
        await governance.setGovernor(user1.address);
        await governance.connect(user1).setLiquidityPoolParameter([1]);

        expect(await governance.isFastCreationEnabled()).to.be.true;
        await governance.connect(user1).setLiquidityPoolParameter([0]);
        expect(await governance.isFastCreationEnabled()).to.be.false;

        await expect(governance.setLiquidityPoolParameter([1])).to.be.revertedWith("only governor is allowed");
    })

})