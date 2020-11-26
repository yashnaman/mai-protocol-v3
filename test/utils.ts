import { ethers } from "hardhat";
import { getDefaultProvider, Signer } from "ethers";

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

export async function getLinkedPerpetualFactory() {
    const AMMTradeModule = await createContract("contracts/module/AMMTradeModule.sol:AMMTradeModule");
    const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
    const OrderModule = await createContract("contracts/module/OrderModule.sol:OrderModule");
    const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
    const TradeModule = await createContract("contracts/module/TradeModule.sol:TradeModule", [], { AMMTradeModule: AMMTradeModule.address });
    return await ethers.getContractFactory("contracts/Perpetual.sol:Perpetual", {
        libraries: {
            AMMTradeModule: AMMTradeModule.address,
            FundingModule: FundingModule.address,
            ParameterModule: ParameterModule.address,
            TradeModule: TradeModule.address,
            OrderModule: OrderModule.address,
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