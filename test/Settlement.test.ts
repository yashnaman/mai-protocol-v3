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
    let user2;
    let user3;
    let oracle;
    let settlement;
    let TestSettlement;

    beforeEach(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        oracle = await createContract("OracleWrapper", [erc20.address]);
        const FundingModule = await createContract("FundingModule");
        const ParameterModule = await createContract("ParameterModule");
        const SettlementModule = await createContract("SettlementModule");
        TestSettlement = await createFactory("TestSettlement", { FundingModule, ParameterModule, SettlementModule });
        settlement = await TestSettlement.deploy(oracle.address);
    })

    it("freeze price ", async () => {
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

    it("clear account", async () => {
        var now = Math.floor(Date.now() / 1000);
        await oracle.setIndexPrice(toWei("500"), now);
        await oracle.setMarkPrice(toWei("500"), now);

        await settlement.initializeMarginAccount(user1.address, toWei("100"), toWei("0.1"), toWei("0")); // 100 + 50
        await settlement.initializeMarginAccount(user2.address, toWei("200"), toWei("0.2"), toWei("0")); // 200 + 100
        await settlement.initializeMarginAccount(user3.address, toWei("300"), toWei("0.3"), toWei("0")); // 300 + 150

        await settlement.registerActiveAccount(user1.address);
        await settlement.registerActiveAccount(user2.address);
        await settlement.registerActiveAccount(user3.address);

        await settlement.setEmergency();

        expect(await settlement.activeAccountCount()).to.equal(3);
        const traders = await settlement.listActiveAccounts(0, 3);
        expect(traders[0]).to.equal(user1.address);
        expect(traders[1]).to.equal(user2.address);
        expect(traders[2]).to.equal(user3.address);

        await expect(settlement.clearMarginAccount("0x0000000000000000000000000000000000000000")).to.be.revertedWith("invalid trader address");
        await expect(settlement.clearMarginAccount(user0.address)).to.be.revertedWith("trader is not registered");
        await settlement.clearMarginAccount(user1.address);
        expect(await settlement.activeAccountCount()).to.equal(2);

    })
});