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
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("1")],
        )
    })

    it('setPerpetualBaseParameter', async () => {
        await governance.setGovernor(user0.address);
        expect(await governance.initialMarginRate(0)).to.equal(toWei("0.1"));
        await governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0.05"));
        expect(await governance.initialMarginRate(0)).to.equal(toWei("0.05"));

        expect(await governance.maintenanceMarginRate(0)).to.equal(toWei("0.05"));
        await governance.setPerpetualBaseParameter(0, toBytes32("maintenanceMarginRate"), toWei("0.025"));
        expect(await governance.maintenanceMarginRate(0)).to.equal(toWei("0.025"));

        expect(await governance.operatorFeeRate(0)).to.equal(toWei("0.001"));
        await governance.setPerpetualBaseParameter(0, toBytes32("operatorFeeRate"), toWei("0.002"));
        expect(await governance.operatorFeeRate(0)).to.equal(toWei("0.002"));

        expect(await governance.lpFeeRate(0)).to.equal(toWei("0.001"));
        await governance.setPerpetualBaseParameter(0, toBytes32("lpFeeRate"), toWei("0.002"));
        expect(await governance.lpFeeRate(0)).to.equal(toWei("0.002"));

        expect(await governance.referralRebateRate(0)).to.equal(toWei("0.2"));
        await governance.setPerpetualBaseParameter(0, toBytes32("referralRebateRate"), toWei("0.5"));
        expect(await governance.referralRebateRate(0)).to.equal(toWei("0.5"));

        expect(await governance.liquidationPenaltyRate(0)).to.equal(toWei("0.02"));
        await governance.setPerpetualBaseParameter(0, toBytes32("liquidationPenaltyRate"), toWei("0.01"));
        expect(await governance.liquidationPenaltyRate(0)).to.equal(toWei("0.01"));

        expect(await governance.keeperGasReward(0)).to.equal(toWei("0.00000002"));
        await governance.setPerpetualBaseParameter(0, toBytes32("keeperGasReward"), toWei("1"));
        expect(await governance.keeperGasReward(0)).to.equal(toWei("1"));
    })

    it('setPerpetualBaseParameter - exception', async () => {
        await governance.setGovernor(user1.address);
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0.2"))).to.be.revertedWith("only governor is allowed");

        await governance.setGovernor(user0.address);
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("keyNotExist"), toWei("0.2"))).to.be.revertedWith("key not found");

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0.11"))).to.be.revertedWith("increasing initial margin rate is not allowed");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0.04"))).to.be.revertedWith("mmr should be lower than imr");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0"))).to.be.revertedWith("imr should be greater than 0");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("-1"))).to.be.revertedWith("imr should be greater than 0");
        await governance.setPerpetualBaseParameter(0, toBytes32("initialMarginRate"), toWei("0.05"));

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("maintenanceMarginRate"), toWei("0.51"))).to.be.revertedWith("increasing maintenance margin rate is not allowed");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("maintenanceMarginRate"), toWei("0"))).to.be.revertedWith("mmr should be greater than 0");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("maintenanceMarginRate"), toWei("-1"))).to.be.revertedWith("mmr should be greater than 0");

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("operatorFeeRate"), toWei("-1"))).to.be.revertedWith("ofr should be within \\[0, 0.01\\]");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("operatorFeeRate"), toWei("0.011"))).to.be.revertedWith("ofr should be within \\[0, 0.01\\]");

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("lpFeeRate"), toWei("-1"))).to.be.revertedWith("lp should be within \\[0, 0.01\\]");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("lpFeeRate"), toWei("0.011"))).to.be.revertedWith("lp should be within \\[0, 0.01\\]");

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("liquidationPenaltyRate"), toWei("-1"))).to.be.revertedWith("lpr should be non-negative and lower than mmr");
        await expect(governance.setPerpetualBaseParameter(0, toBytes32("liquidationPenaltyRate"), toWei("0.051"))).to.be.revertedWith("lpr should be non-negative and lower than mmr");

        await expect(governance.setPerpetualBaseParameter(0, toBytes32("keeperGasReward"), toWei("-1"))).to.be.revertedWith("kgr should be non-negative");
    })

    it('setPerpetualRiskParameter', async () => {
        await governance.setGovernor(user0.address);
        await governance.setPerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.5"), toWei("0"), toWei("1"));
        expect(await governance.halfSpread(0)).to.equal(toWei("0.5"));

        await governance.setPerpetualRiskParameter(0, toBytes32("openSlippageFactor"), toWei("0.6"), toWei("0"), toWei("1"));
        expect(await governance.openSlippageFactor(0)).to.equal(toWei("0.6"));

        await governance.setPerpetualRiskParameter(0, toBytes32("closeSlippageFactor"), toWei("0.45"), toWei("0"), toWei("1"));
        expect(await governance.closeSlippageFactor(0)).to.equal(toWei("0.45"));

        await governance.setPerpetualRiskParameter(0, toBytes32("fundingRateLimit"), toWei("0.1"), toWei("0"), toWei("1"));
        expect(await governance.fundingRateLimit(0)).to.equal(toWei("0.1"));

        await governance.setPerpetualRiskParameter(0, toBytes32("ammMaxLeverage"), toWei("5"), toWei("0"), toWei("10"));
        expect(await governance.ammMaxLeverage(0)).to.equal(toWei("5"));

        await governance.setPerpetualRiskParameter(0, toBytes32("maxClosePriceDiscount"), toWei("0.05"), toWei("0"), toWei("0.99"));
        expect(await governance.maxClosePriceDiscount(0)).to.equal(toWei("0.05"));
    })

    it('setPerpetualRiskParameter - exception', async () => {
        await governance.setGovernor(user1.address);
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.05"), toWei("0"), toWei("1"))).to.be.revertedWith("only governor is allowed");

        await governance.setGovernor(user0.address);
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.05"), toWei("0.06"), toWei("1"))).to.be.revertedWith("value is out of range");
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.05"), toWei("0"), toWei("0.04"))).to.be.revertedWith("value is out of range");

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("keyNotExist"), toWei("0.2"), toWei("0"), toWei("1"))).to.be.revertedWith("key not found");
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("-1"), toWei("-1"), toWei("1"))).to.be.revertedWith("hs shoud be greater than 0 and less than 1");

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("openSlippageFactor"), toWei("0"), toWei("0"), toWei("1"))).to.be.revertedWith("osf shoud be greater than 0");
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("openSlippageFactor"), toWei("-1"), toWei("-2"), toWei("1"))).to.be.revertedWith("osf shoud be greater than 0");
        await governance.setPerpetualRiskParameter(0, toBytes32("openSlippageFactor"), toWei("0.5"), toWei("0"), toWei("1"));

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("closeSlippageFactor"), toWei("0"), toWei("0"), toWei("1"))).to.be.revertedWith("csf should be within \\(0, b1\\]");
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("closeSlippageFactor"), toWei("-1"), toWei("-2"), toWei("1"))).to.be.revertedWith("csf should be within \\(0, b1\\]");
        await governance.setPerpetualRiskParameter(0, toBytes32("closeSlippageFactor"), toWei("0.4"), toWei("0"), toWei("1"));

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("fundingRateLimit"), toWei("-1"), toWei("-1"), toWei("1"))).to.be.revertedWith("frl should be greater than 0");

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("ammMaxLeverage"), toWei("0"), toWei("0"), toWei("1"))).to.be.revertedWith("aml should be greater than 0");

        await expect(governance.setPerpetualRiskParameter(0, toBytes32("maxClosePriceDiscount"), toWei("1"), toWei("0"), toWei("1"))).to.be.revertedWith("mcpd shoud be greater than 0 and less than 1");
        await expect(governance.setPerpetualRiskParameter(0, toBytes32("maxClosePriceDiscount"), toWei("-1"), toWei("-2"), toWei("0.5"))).to.be.revertedWith("mcpd shoud be greater than 0 and less than 1");
        await governance.setPerpetualRiskParameter(0, toBytes32("maxClosePriceDiscount"), toWei("0.5"), toWei("0"), toWei("0.99"));
    })

    it('updatePerpetualRiskParameter', async () => {
        await governance.setOperatorNoAuth(user1.address);
        await expect(governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.05"))).to.be.revertedWith("only operator is allowed");

        await governance.setOperatorNoAuth(user0.address);
        await governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.05"));
        await governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0"));
        await governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.1"));

        await expect(governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("0.15"))).to.be.revertedWith("value is out of range");
        await expect(governance.updatePerpetualRiskParameter(0, toBytes32("halfSpread"), toWei("-1"))).to.be.revertedWith("value is out of range");
    })

    it("setLiquidityPoolParameter", async () => {
        await governance.setGovernor(user1.address);
        await governance.connect(user1).setLiquidityPoolParameter(toBytes32("isFastCreationEnabled"), 1);
        expect(await governance.isFastCreationEnabled()).to.be.true;
        await governance.connect(user1).setLiquidityPoolParameter(toBytes32("isFastCreationEnabled"), 0);
        expect(await governance.isFastCreationEnabled()).to.be.false;

        await expect(governance.setLiquidityPoolParameter(toBytes32("isFastCreationEnabled"), 1)).to.be.revertedWith("only governor is allowed");
        await expect(governance.connect(user1).setLiquidityPoolParameter(toBytes32("notExist"), 1)).to.be.revertedWith("key not found");
    })

})