import { ethers } from "hardhat";

const toWei = ethers.utils.parseEther;
const fromWei = ethers.utils.formatEther;

async function createContract(path, args = [], libraries = {}) {
    const factory = await ethers.getContractFactory(path, { libraries: libraries });
    const deployed = await factory.deploy(...args);
    return deployed;
}

async function main() {

    const accounts = await ethers.getSigners();
    const user1 = await accounts[0].getAddress();

    // We get the contract to deploy
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

    await perpetual.initialize(
        user1,
        oracle.address,
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        [
            toWei("0.1"),
            toWei("0.05"),
            toWei("0.001"),
            toWei("0.001"),
            toWei("0.2"),
            toWei("0.02"),
            toWei("0.00000002"),
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
    console.log("oracle deployed to:", oracle.address);
    console.log("collateral deployed to:", collateral.address);
    console.log("perpetual deployed to:", perpetual.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });