const { ethers } = require("hardhat");
const { expect } = require("chai");

import {
    toWei,
    toBytes32,
    getAccounts,
    createContract,
    createContractFactory,
} from './utils';

describe('Storage', () => {
    let accounts;
    let user0;
    let user1;
    let storage;
    let TestStorage;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];

        const ParameterModule = await createContract("ParameterModule")
        const FundingModule = await createContract("FundingModule")
        TestStorage = await createContractFactory(
            "TestStorage",
            {
                FundingModule: FundingModule.address,
                ParameterModule: ParameterModule.address
            }
        );
        storage = await TestStorage.deploy();
    })

    it("initialize", async () => {
        const erc20 = await createContract("contracts/test/CustomERC20.sol:CustomERC20", ["collateral", "CTK", 18]);
        const oracle = await createContract("contracts/oracle/mock/OracleWrapper.sol:OracleWrapper", [erc20.address]);
        await storage.initialize(
            user0.address,
            oracle.address,
            user1.address,
            user1.address,
            [
                toWei("0.1"),
                toWei("0.05"),
                toWei("0.001"),
                toWei("0.001"),
                toWei("0.2"),
                toWei("0.02"),
                toWei("1"),
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