import { ethers } from "hardhat";
import { getDefaultProvider, Signer } from "ethers";

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }

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

export async function deployTestEnviron() {
    const collateral = await createContract("contracts/test/CustomERC20.sol:CustomERC20", ["collateral", "CTK", 18]);
    const oracle = await createContract("contracts/oracle/mock/OracleWrapper.sol:OracleWrapper", [collateral.address]);

    const OrderUtils = await createContract("contracts/libraries/OrderUtils.sol:OrderUtils");
    const AMMTradeModule = await createContract("contracts/module/AMMTradeModule.sol:AMMTradeModule");
    const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
    const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
    const TradeModule = await createContract("contracts/module/TradeModule.sol:TradeModule", [], { AMMTradeModule: AMMTradeModule.address });

    const perpetual = await createContract("contracts/Perpetual.sol:Perpetual", [], {
        OrderUtils: OrderUtils.address,
        AMMTradeModule: AMMTradeModule.address,
        FundingModule: FundingModule.address,
        ParameterModule: ParameterModule.address,
        TradeModule: TradeModule.address,
    });

    return {
        collateral,
        oracle,
        perpetual
    }
}