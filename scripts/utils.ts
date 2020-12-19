const { ethers } = require("hardhat");
import { getDefaultProvider, Signer } from "ethers";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { PoolCreator } from "../typechain/PoolCreator"
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

export async function createLiquidityPoolFactory() {
    const CollateralModule = await createContract("CollateralModule")
    const AMMModule = await createContract("AMMModule", [], { CollateralModule });
    const FundingModule = await createContract("FundingModule", [], { AMMModule });
    const OrderModule = await createContract("OrderModule");
    const OracleModule = await createContract("OracleModule");
    const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule });
    const ParameterModule = await createContract("ParameterModule");
    const PerpetualModule = await createContract("PerpetualModule", [], { ParameterModule });
    const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule });
    const LiquidationModule = await createContract("LiquidationModule", [], { LiquidityPoolModule, AMMModule, CollateralModule, OracleModule, TradeModule });
    const MarginModule = await createContract("MarginModule", [], { PerpetualModule, LiquidityPoolModule, CollateralModule });
    const SettlementModule = await createContract("SettlementModule", [], { LiquidityPoolModule, CollateralModule });
    return await createFactory("LiquidityPool", {
        AMMModule,
        FundingModule,
        OrderModule,
        ParameterModule,
        SettlementModule,
        TradeModule,
        LiquidityPoolModule,
        LiquidationModule,
        MarginModule,
        PerpetualModule,
    });
}