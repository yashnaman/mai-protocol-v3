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

export async function createContract(path: string, args: any[] = [], libraries = {}): Promise<any> {
    const factory = await ethers.getContractFactory(path, { libraries: libraries });
    const deployed = await factory.deploy(...args);
    return deployed;
}

export async function createContractFactory(path, libraries = {}) {
    return await ethers.getContractFactory(path, { libraries: libraries })
}

export async function getLinkedPerpetualFactory() {
    const AMMTradeModule = await createContract("contracts/module/AMMTradeModule.sol:AMMTradeModule");
    const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
    const OrderModule = await createContract("contracts/module/OrderModule.sol:OrderModule");
    const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
    const SettlementModule = await createContract("contracts/module/SettlementModule.sol:SettlementModule");
    const TradeModule = await createContract("contracts/module/TradeModule.sol:TradeModule", [], { AMMTradeModule: AMMTradeModule.address });
    return await ethers.getContractFactory("contracts/Perpetual.sol:Perpetual", {
        libraries: {
            AMMTradeModule: AMMTradeModule.address,
            FundingModule: FundingModule.address,
            ParameterModule: ParameterModule.address,
            TradeModule: TradeModule.address,
            OrderModule: OrderModule.address,
            SettlementModule: SettlementModule.address,
        }
    });
}

export async function createTestPerpetual() {
    const factory = await getLinkedPerpetualFactory();
    const deployed = await factory.deploy();
    return deployed;
}

export async function createPerpetualMaker(governor, shareToken, perpetual, vault, vaultFeeRate) {
    return await createContract(
        "contracts/factory/PerpetualMaker.sol:PerpetualMaker",
        [
            governor.address,
            shareToken.address,
            perpetual.address,
            vault.address,
            vaultFeeRate,
        ]
    );
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

        this.collateral = await createContract("contracts/test/CustomERC20.sol:CustomERC20", ["CTK", "CTK", 18]);
        this.oracle = await createContract("contracts/oracle/mock/OracleWrapper.sol:OracleWrapper", [this.collateral.address]);

        var shareTemplate = await createContract("contracts/governance/ShareToken.sol:ShareToken");
        var govTemplate = await createContract("contracts/governance/Governor.sol:Governor");
        var perpTemplate = await createTestPerpetual();
        this.perpetualMaker = await await createContract(
            "contracts/factory/PerpetualMaker.sol:PerpetualMaker",
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
        const factory = await getLinkedPerpetualFactory();
        return await factory.attach(all[all.length - 1]);
    }

    async perpareCollateral(user, perp, amount) {
        this.collateral.mint(user.address, amount);
        const userCTK = await CustomErc20Factory.connect(this.collateral.address, user);
        await userCTK.approve(perp.address, toWei("99999999999999999999"));
    }
}