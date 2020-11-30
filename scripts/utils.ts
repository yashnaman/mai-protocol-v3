const { ethers } = require("hardhat");
import { getDefaultProvider, Signer } from "ethers";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { PerpetualFactory } from "../typechain/PerpetualFactory"
import { BrokerRelayFactory } from "../typechain/BrokerRelayFactory";

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }
export function toBytes32(s) { return ethers.utils.formatBytes32String(s); }
export function fromBytes32(s) { return ethers.utils.parseBytes32String(s); }

export async function getAccounts(): Promise<any[]> {
    const accounts = await ethers.getSigners();
    const users = [];
    accounts.forEach(element => {
        users.push(element.address);
    });
    return accounts;
}


export async function createFactory(path, libraries = {}) {
    const parsed = {}
    for (var name in libraries) {
        parsed[name] = libraries[name].address;
    }
    return await ethers.getContractFactory(path, { libraries: parsed })
}

export async function createContract(path, args = [], libraries = {}) {
    const factory = await createFactory(path, libraries);
    const deployed = await factory.deploy(...args);
    return deployed;
}

export async function createPerpetualFactory() {
    const AMMTradeModule = await createContract("AMMTradeModule");
    const FundingModule = await createContract("FundingModule");
    const OrderModule = await createContract("OrderModule");
    const ParameterModule = await createContract("ParameterModule");
    const SettlementModule = await createContract("SettlementModule");
    const TradeModule = await createContract("TradeModule", [], { AMMTradeModule });
    return await createFactory("Perpetual", {
        AMMTradeModule,
        FundingModule,
        OrderModule,
        ParameterModule,
        SettlementModule,
        TradeModule,
    });
}

export class TestSet {
    accounts;
    operator;
    user1;
    user2;
    user3;
    vault;

    collateral;
    oracle
    perpetualMaker

    async initialzie(vaultFeeRate) {
        this.accounts = await ethers.getSigners();
        this.operator = this.accounts[0];
        this.vault = this.accounts[9];

        this.collateral = await createContract("CustomERC20", ["CTK", "CTK", 18]);
        this.oracle = await createContract("OracleWrapper", [this.collateral.address]);

        var shareTemplate = await createContract("ShareToken");
        var govTemplate = await createContract("Governor");
        var perpTemplate = (await createPerpetualFactory()).deploy();
        this.perpetualMaker = await await createContract(
            "PerpetualMaker",
            [
                govTemplate.address,
                shareTemplate.address,
                perpTemplate.address,
                this.vault.address,
                vaultFeeRate,
            ]
        );
    }

    async createDefaultPerpetual() {
        await this.perpetualMaker.createPerpetual(
            this.oracle.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1")],
            [toWei("0.001"), toWei("0.2"), toWei("0.1"), toWei("0.005"), toWei("5")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
            998,
        );
        const count = await this.perpetualMaker.totalPerpetualCount();
        const all = await this.perpetualMaker.listPerpetuals(0, count.toString());
        const factory = await createPerpetualFactory();
        return await factory.attach(all[all.length - 1]);
    }

    async perpareCollateral(user, perp, amount) {
        this.collateral.mint(user.address, amount);
        const userCTK = await CustomErc20Factory.connect(this.collateral.address, user);
        await userCTK.approve(perp.address, toWei("99999999999999999999"));
    }
}