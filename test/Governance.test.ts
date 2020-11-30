const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
    createContractFactory,
} from './utils';

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
        referrerRebateRate: toWei("0"),
    }
    const riskParameters = {
        halfSpreadRate: toWei("0.001"),
        beta1: toWei("0.2"),
        beta2: toWei("0.1"),
        fundingRateCoefficient: toWei("0.005"),
        targetLeverage: toWei("5"),
    }

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];

        const FundingModule = await createContract("FundingModule")
        const ParameterModule = await createContract("ParameterModule")
        TestGovernance = await createContractFactory(
            "TestGovernance",
            {
                FundingModule: FundingModule.address,
                ParameterModule: ParameterModule.address
            }
        );
    })

    beforeEach(async () => {
        governance = await TestGovernance.deploy();
        await governance.initializeParameters(
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        )
    })

    it('updateCoreParameter', async () => {
        await governance.setGovernor(user0.address);
        expect(await governance.initialMarginRate()).to.equal(toWei("0.1"));
        await governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("0.2"));
        expect(await governance.initialMarginRate()).to.equal(toWei("0.2"));

        expect(await governance.maintenanceMarginRate()).to.equal(toWei("0.05"));
        await governance.updateCoreParameter(toBytes32("maintenanceMarginRate"), toWei("0.075"));
        expect(await governance.maintenanceMarginRate()).to.equal(toWei("0.075"));

        expect(await governance.operatorFeeRate()).to.equal(toWei("0.001"));
        await governance.updateCoreParameter(toBytes32("operatorFeeRate"), toWei("0.002"));
        expect(await governance.operatorFeeRate()).to.equal(toWei("0.002"));

        expect(await governance.lpFeeRate()).to.equal(toWei("0.001"));
        await governance.updateCoreParameter(toBytes32("lpFeeRate"), toWei("0.002"));
        expect(await governance.lpFeeRate()).to.equal(toWei("0.002"));

        expect(await governance.referrerRebateRate()).to.equal(toWei("0.2"));
        await governance.updateCoreParameter(toBytes32("referrerRebateRate"), toWei("0.5"));
        expect(await governance.referrerRebateRate()).to.equal(toWei("0.5"));

        expect(await governance.liquidationPenaltyRate()).to.equal(toWei("0.02"));
        await governance.updateCoreParameter(toBytes32("liquidationPenaltyRate"), toWei("0.05"));
        expect(await governance.liquidationPenaltyRate()).to.equal(toWei("0.05"));

        expect(await governance.keeperGasReward()).to.equal(toWei("0.00000002"));
        await governance.updateCoreParameter(toBytes32("keeperGasReward"), toWei("1"));
        expect(await governance.keeperGasReward()).to.equal(toWei("1"));
    })

    it('updateCoreParameter - exception', async () => {
        await governance.setGovernor(user1.address);
        await expect(governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("0.2"))).to.be.revertedWith("only governor is allowed");

        await governance.setGovernor(user0.address);
        await expect(governance.updateCoreParameter(toBytes32("keyNotExist"), toWei("0.2"))).to.be.revertedWith("key not found");

        await expect(governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("0.04"))).to.be.revertedWith("mmr should be lower than imr");
        await expect(governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("0"))).to.be.revertedWith("imr should be within \\(0, 1\\]");
        await expect(governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("-1"))).to.be.revertedWith("imr should be within \\(0, 1\\]");
        await expect(governance.updateCoreParameter(toBytes32("initialMarginRate"), toWei("1.01"))).to.be.revertedWith("imr should be within \\(0, 1\\]");

        await expect(governance.updateCoreParameter(toBytes32("maintenanceMarginRate"), toWei("0.11"))).to.be.revertedWith("mmr should be lower than imr");
        await expect(governance.updateCoreParameter(toBytes32("maintenanceMarginRate"), toWei("0"))).to.be.revertedWith("mmr should be within \\(0, 1\\]");
        await expect(governance.updateCoreParameter(toBytes32("maintenanceMarginRate"), toWei("-1"))).to.be.revertedWith("mmr should be within \\(0, 1\\]");
        await expect(governance.updateCoreParameter(toBytes32("maintenanceMarginRate"), toWei("1.01"))).to.be.revertedWith("mmr should be within \\(0, 1\\]");

        await expect(governance.updateCoreParameter(toBytes32("operatorFeeRate"), toWei("-1"))).to.be.revertedWith("ofr should be within \\[0, 0.01\\]");
        await expect(governance.updateCoreParameter(toBytes32("operatorFeeRate"), toWei("0.011"))).to.be.revertedWith("ofr should be within \\[0, 0.01\\]");

        await expect(governance.updateCoreParameter(toBytes32("lpFeeRate"), toWei("-1"))).to.be.revertedWith("lp should be within \\[0, 0.01\\]");
        await expect(governance.updateCoreParameter(toBytes32("lpFeeRate"), toWei("0.011"))).to.be.revertedWith("lp should be within \\[0, 0.01\\]");

        await expect(governance.updateCoreParameter(toBytes32("liquidationPenaltyRate"), toWei("-1"))).to.be.revertedWith("lpr should be non-negative and lower than mmr");
        await expect(governance.updateCoreParameter(toBytes32("liquidationPenaltyRate"), toWei("0.051"))).to.be.revertedWith("lpr should be non-negative and lower than mmr");

        await expect(governance.updateCoreParameter(toBytes32("keeperGasReward"), toWei("-1"))).to.be.revertedWith("kgr should be non-negative");
    })

    it('updateRiskParameter', async () => {
        await governance.setGovernor(user0.address);
        await governance.updateRiskParameter(toBytes32("halfSpreadRate"), toWei("0.5"), toWei("0"), toWei("1"));
        expect(await governance.halfSpreadRate()).to.equal(toWei("0.5"));

        await governance.updateRiskParameter(toBytes32("beta1"), toWei("0.6"), toWei("0"), toWei("1"));
        expect(await governance.beta1()).to.equal(toWei("0.6"));

        await governance.updateRiskParameter(toBytes32("beta2"), toWei("0.45"), toWei("0"), toWei("1"));
        expect(await governance.beta2()).to.equal(toWei("0.45"));

        await governance.updateRiskParameter(toBytes32("fundingRateCoefficient"), toWei("0.1"), toWei("0"), toWei("1"));
        expect(await governance.fundingRateCoefficient()).to.equal(toWei("0.1"));

        await governance.updateRiskParameter(toBytes32("targetLeverage"), toWei("5"), toWei("0"), toWei("10"));
        expect(await governance.targetLeverage()).to.equal(toWei("5"));
    })

    it('updateRiskParameter - exception', async () => {
        await governance.setGovernor(user1.address);
        await expect(governance.updateRiskParameter(toBytes32("halfSpreadRate"), toWei("0.05"), toWei("0"), toWei("1"))).to.be.revertedWith("only governor is allowed");

        await governance.setGovernor(user0.address);
        await expect(governance.updateRiskParameter(toBytes32("halfSpreadRate"), toWei("0.05"), toWei("0.06"), toWei("1"))).to.be.revertedWith("value is out of range");
        await expect(governance.updateRiskParameter(toBytes32("halfSpreadRate"), toWei("0.05"), toWei("0"), toWei("0.04"))).to.be.revertedWith("value is out of range");

        await expect(governance.updateRiskParameter(toBytes32("keyNotExist"), toWei("0.2"), toWei("0"), toWei("1"))).to.be.revertedWith("key not found");
        await expect(governance.updateRiskParameter(toBytes32("halfSpreadRate"), toWei("-1"), toWei("-1"), toWei("1"))).to.be.revertedWith("hsr shoud be greater than 0");

        await expect(governance.updateRiskParameter(toBytes32("beta1"), toWei("0"), toWei("0"), toWei("1"))).to.be.revertedWith("b1 should be within \\(0, 1\\)");
        await expect(governance.updateRiskParameter(toBytes32("beta1"), toWei("1"), toWei("0"), toWei("1"))).to.be.revertedWith("b1 should be within \\(0, 1\\)");
        await governance.updateRiskParameter(toBytes32("beta1"), toWei("0.5"), toWei("0"), toWei("1"));

        await expect(governance.updateRiskParameter(toBytes32("beta2"), toWei("0"), toWei("0"), toWei("1"))).to.be.revertedWith("b2 should be within \\(0, b1\\)");
        await expect(governance.updateRiskParameter(toBytes32("beta2"), toWei("1"), toWei("0"), toWei("1"))).to.be.revertedWith("b2 should be within \\(0, b1\\)");
        await expect(governance.updateRiskParameter(toBytes32("beta2"), toWei("0.5"), toWei("0"), toWei("1"))).to.be.revertedWith("b2 should be within \\(0, b1\\)");
        await governance.updateRiskParameter(toBytes32("beta2"), toWei("0.4"), toWei("0"), toWei("1"));

        await expect(governance.updateRiskParameter(toBytes32("fundingRateCoefficient"), toWei("-1"), toWei("-1"), toWei("1"))).to.be.revertedWith("frc should be greater than 0");

        await expect(governance.updateRiskParameter(toBytes32("targetLeverage"), toWei("1"), toWei("0"), toWei("1"))).to.be.revertedWith("tl should be within \\(1, 10\\)");
        await expect(governance.updateRiskParameter(toBytes32("targetLeverage"), toWei("10"), toWei("0"), toWei("10"))).to.be.revertedWith("tl should be within \\(1, 10\\)");
    })

    it('adjustRiskParameter', async () => {
        await governance.setOperator(user1.address);
        await expect(governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("0.05"))).to.be.revertedWith("only operator is allowed");

        await governance.setOperator(user0.address);
        await governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("0.05"));
        await governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("0"));
        await governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("0.1"));

        await expect(governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("0.15"))).to.be.revertedWith("value is out of range");
        await expect(governance.adjustRiskParameter(toBytes32("halfSpreadRate"), toWei("-1"))).to.be.revertedWith("value is out of range");
    })
})