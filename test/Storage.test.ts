const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

describe('Storage', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let storage;
    let TestStorage;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];

        const ParameterModule = await createContract("ParameterModule")
        const CollateralModule = await createContract("CollateralModule")
        const AMMModule = await createContract("AMMModule", [], { CollateralModule })
        const FundingModule = await createContract("FundingModule", [], { AMMModule })
        const PerpetualModule = await createContract("PerpetualModule", [], { ParameterModule })
        TestStorage = await createFactory("TestStorage", { FundingModule, PerpetualModule });
        storage = await TestStorage.deploy();
    })

    it("initialize", async () => {
        const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        const oracle = await createContract("OracleWrapper", [erc20.address]);
        await storage.initializePerpetual(
            oracle.address,
            [
                toWei("0.1"),
                toWei("0.05"),
                toWei("0.001"),
                toWei("0.001"),
                toWei("0.2"),
                toWei("0.02"),
                toWei("1"),
                toWei("0.5"),
            ],
            [
                toWei("0.01"),
                toWei("0.1"),
                toWei("0.06"),
                toWei("0.1"),
                toWei("5"),
            ],
            [
                toWei("0"),
                toWei("0"),
                toWei("0"),
                toWei("0"),
                toWei("0"),
            ],
            [
                toWei("0.1"),
                toWei("0.2"),
                toWei("0.2"),
                toWei("0.5"),
                toWei("10"),
            ],
        )

        let now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(500, now);
        await oracle.setIndexPrice(500, now);

        const result = await storage.callStatic.getPerpetualInfo(0);

        expect(result.oracle).to.equal(oracle.address);
        expect(result.markPrice).to.equal(500);
        expect(result.indexPrice).to.equal(500);

        const coreParams = result.coreParameters;
        const riskParams = result.riskParameters;

        expect(coreParams[0]).to.equal(toWei("0.1"));
        expect(coreParams[1]).to.equal(toWei("0.05"));
        expect(coreParams[2]).to.equal(toWei("0.001"));
        expect(coreParams[3]).to.equal(toWei("0"));
        expect(coreParams[4]).to.equal(toWei("0.001"));
        expect(coreParams[5]).to.equal(toWei("0.2"));
        expect(coreParams[6]).to.equal(toWei("0.02"));
        expect(coreParams[7]).to.equal(toWei("1"));
        expect(coreParams[8]).to.equal(toWei("0"));
        expect(coreParams[9]).to.equal(toWei("0.5"));

        expect(riskParams[0]).to.equal(toWei("0.01"));
        expect(riskParams[1]).to.equal(toWei("0.1"));
        expect(riskParams[2]).to.equal(toWei("0.06"));
        expect(riskParams[3]).to.equal(toWei("0.1"));
        expect(riskParams[4]).to.equal(toWei("5"));
    })

});