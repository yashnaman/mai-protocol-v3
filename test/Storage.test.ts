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
        const CoreModule = await createContract("CoreModule", [], { CollateralModule })
        const MarketModule = await createContract("MarketModule", [], { ParameterModule })
        TestStorage = await createFactory("TestStorage", { FundingModule, MarketModule });
        storage = await TestStorage.deploy();
    })

    it("initialize", async () => {
        const erc20 = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        // await storage.initializeCore(
        //     erc20.address,
        //     user0.address,
        //     user1.address,
        //     user2.address,
        // );
        const oracle = await createContract("OracleWrapper", [erc20.address]);
        await storage.initializeMarket(
            oracle.address,
            [
                toWei("0.1"),
                toWei("0.05"),
                toWei("0.001"),
                toWei("0.001"),
                toWei("0.2"),
                toWei("0.02"),
                toWei("1"),
                toWei("5"),
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
    })

});