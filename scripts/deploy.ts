import { ethers } from "hardhat";

const toWei = ethers.utils.parseEther;
const fromWei = ethers.utils.formatEther;

async function createContract(path, args = [], libraries = {}) {
    const factory = await ethers.getContractFactory(path, { libraries: libraries });
    const deployed = await factory.deploy(...args);
    return deployed;
}

async function deployCollateral(name, symbol, decimals) {
    return await createContract("contracts/test/CustomERC20.sol:CustomERC20", [name, symbol, decimals]);
}

async function deployOracle(collateral) {
    return await createContract("contracts/oracle/mock/OracleWrapper.sol:OracleWrapper", [collateral.address]);
}

async function deployPerpetual() {
    const OrderModule = await createContract("contracts/module/OrderModule.sol:OrderModule");
    const AMMTradeModule = await createContract("contracts/module/AMMTradeModule.sol:AMMTradeModule");
    const FundingModule = await createContract("contracts/module/FundingModule.sol:FundingModule");
    const ParameterModule = await createContract("contracts/module/ParameterModule.sol:ParameterModule");
    const SettlementModule = await createContract("contracts/module/SettlementModule.sol:SettlementModule");
    const TradeModule = await createContract("contracts/module/TradeModule.sol:TradeModule", [], { AMMTradeModule: AMMTradeModule.address });
    const perpetual = await createContract("contracts/Perpetual.sol:Perpetual", [], {
        OrderModule: OrderModule.address,
        AMMTradeModule: AMMTradeModule.address,
        FundingModule: FundingModule.address,
        ParameterModule: ParameterModule.address,
        TradeModule: TradeModule.address,
        SettlementModule: SettlementModule.address,
    });
    return perpetual;
}

async function deployBrokerRelay() {
    return await createContract("contracts/broker/BrokerRelay.sol:BrokerRelay");
}

async function deployShareToken() {
    return await createContract("contracts/governance/ShareToken.sol:ShareToken");
}

async function deployGovernor() {
    return await createContract("contracts/governance/Governor.sol:Governor");
}


async function deployPerpetualMaker(vault, vaultFeeRate) {
    const perpetual = await deployPerpetual();
    const shareToken = await deployShareToken();
    const governor = await deployGovernor();
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

async function main(accounts: any[]) {
    // ===== mock
    const collateral = await deployCollateral("collateral", "CTK", 18);
    console.log("collateral deployed to:", collateral.address);
    const oracle = await deployOracle(collateral);
    console.log("oracle deployed to:", oracle.address);

    // ===== template
    // const perpetual = await deployPerpetual();
    // console.log("perpetual deployed to:", perpetual.address);
    // const shareToken = await deployShareToken();
    // console.log("shareToken deployed to:", shareToken.address);
    // const governor = await deployGovernor();
    // console.log("governor deployed to:", governor.address);

    // ===== broker
    const brokerRelay = await deployBrokerRelay();
    console.log("brokerRelay deployed to:", brokerRelay.address);

    // ===== maker
    const perpetualMaker = await deployPerpetualMaker(accounts[0], toWei("0.001"));

    const tx = await perpetualMaker.createPerpetual(
        // accounts[0].address,
        oracle.address,
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
        998,
    )
    console.log(await tx.wait());
    console.log("perpetualMaker deployed to :", perpetualMaker.address);

    const n = await perpetualMaker.totalPerpetualCount();
    console.log("totalPerpetualCount        :", n.toString());

    const allPerpetuals = await perpetualMaker.listPerpetuals(0, n.toString());
    allPerpetuals.forEach(element => {
        console.log("address                :", element);
    });
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });