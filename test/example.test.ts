import { ethers } from "hardhat";
import { getDefaultProvider, Signer } from "ethers";

const toWei = ethers.utils.parseEther;
const fromWei = ethers.utils.formatEther;

describe("Example", function () {
    let accounts: Signer[];
    let user1: string
    let user2: string

    before(async function () {
        accounts = await ethers.getSigners();
        user1 = await accounts[0].getAddress();
        user2 = await accounts[0].getAddress();
    });

    let createContract = async (path, args = [], libraries = {}) => {
        const factory = await ethers.getContractFactory(path, { libraries: libraries });
        const deployed = await factory.deploy(...args);
        return deployed;
    }

    let createEnviron = async () => {
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

    it("example", async function () {
        const { perpetual, oracle, collateral } = await createEnviron();
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

        await collateral.mint(user1, toWei("10"));
        await collateral.approve(perpetual.address, toWei("1000"), { from: user1 });
        await perpetual.deposit(user1, toWei("1"));
        console.log(fromWei(await perpetual.callStatic.margin(user1)));
    });
});