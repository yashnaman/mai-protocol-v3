const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

describe('Settlement', () => {
    let accounts;
    let user0;
    let user1;
    let oracle;
    let settlement;
    let TestSettlement;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];

        const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        oracle = await createContract("OracleWrapper", [erc20.address]);
        const FundingModule = await createContract("FundingModule");
        const ParameterModule = await createContract("ParameterModule");
        const SettlementModule = await createContract("SettlementModule");
        TestSettlement = await createFactory("TestSettlement", { FundingModule, ParameterModule, SettlementModule });
        settlement = await TestSettlement.deploy(oracle.address);
    })

    it("freeze price", async () => {
        var now = Math.floor(Date.now() / 1000);

        await settlement.initializeMarginAccount(user1.address, toWei("0"), toWei("1"), toWei("0"));
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);
        expect(await settlement.callStatic.margin(user1.address)).to.equal(toWei("500"));

        await oracle.setIndexPrice(toWei("400"), now);
        await oracle.setMarkPrice(toWei("400"), now);
        expect(await settlement.callStatic.margin(user1.address)).to.equal(toWei("400"));

        await oracle.setIndexPrice(toWei("600"), now);
        await oracle.setMarkPrice(toWei("600"), now);
        expect(await settlement.callStatic.margin(user1.address)).to.equal(toWei("600"));

        await settlement.setEmergency();
        expect(await settlement.callStatic.margin(user1.address)).to.equal(toWei("600"));
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);
        expect(await settlement.callStatic.margin(user1.address)).to.equal(toWei("600"));
    })

    it("clear account")
});