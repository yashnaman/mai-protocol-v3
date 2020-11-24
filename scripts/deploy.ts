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
    const TradeModule = await createContract("contracts/module/TradeModule.sol:TradeModule", [], { AMMTradeModule: AMMTradeModule.address });
    const perpetual = await createContract("contracts/Perpetual.sol:Perpetual", [], {
        OrderModule: OrderModule.address,
        AMMTradeModule: AMMTradeModule.address,
        FundingModule: FundingModule.address,
        ParameterModule: ParameterModule.address,
        TradeModule: TradeModule.address,
    });
    // await perpetual.initialize(
    //     operator,
    //     oracle.address,
    //     "0x0000000000000000000000000000000000000000",
    //     "0x0000000000000000000000000000000000000000",
    //     [
    //         toWei("0.1"),
    //         toWei("0.05"),
    //         toWei("0.001"),
    //         toWei("0.001"),
    //         toWei("0.2"),
    //         toWei("0.02"),
    //         toWei("0.00000002"),
    //     ],
    //     [
    //         toWei("0.01"),
    //         toWei("0.1"),
    //         toWei("0.06"),
    //         toWei("0.1"),
    //         toWei("5"),
    //     ],
    //     [
    //         toWei("0"),
    //         toWei("0"),
    //         toWei("0"),
    //         toWei("0"),
    //         toWei("0"),
    //     ],
    //     [
    //         toWei("0.1"),
    //         toWei("0.2"),
    //         toWei("0.2"),
    //         toWei("0.5"),
    //         toWei("10"),
    //     ],
    // )
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


async function deployPerpetualMaker() {
    // perpetual deployed to: 0x938c74cDffc1b744fF4519543af2C9d99cF143E5
    // shareToken deployed to: 0x0F4CBdCc847e0cd4f6eb3A69f615859D8c5D71E8
    // governor deployed to: 0x56720Bd590cE768B13E07fF047B3c5fB9e7952e3
    return await createContract(
        "contracts/factory/PerpetualMaker.sol:PerpetualMaker",
        [
            "0x56720Bd590cE768B13E07fF047B3c5fB9e7952e3",
            "0x0F4CBdCc847e0cd4f6eb3A69f615859D8c5D71E8",
            "0x938c74cDffc1b744fF4519543af2C9d99cF143E5"
        ]
    );
}

async function main(accounts: any[]) {
    // ===== mock
    // const collateral = await deployCollateral("collateral", "CTK", 18);
    // console.log("collateral deployed to:", collateral.address);
    // const oracle = await deployOracle(collateral);
    // console.log("oracle deployed to:", oracle.address);

    // ===== template
    // const perpetual = await deployPerpetual();
    // console.log("perpetual deployed to:", perpetual.address);
    // const shareToken = await deployShareToken();
    // console.log("shareToken deployed to:", shareToken.address);
    // const governor = await deployGovernor();
    // console.log("governor deployed to:", governor.address);

    // ===== broker
    // const brokerRelay = await deployBrokerRelay();
    // console.log("brokerRelay deployed to:", brokerRelay.address);

    // ===== maker
    const perpetualMaker = deployPerpetualMaker();
    console.log("perpetualMaker deployed to:", perpetualMaker.address);
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });