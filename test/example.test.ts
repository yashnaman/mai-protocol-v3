import { ethers } from "hardhat";
import { Signer } from "ethers";

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
		// const libTradeImpFactory = await createFromFactory(
		// 	"contracts/implementation/TradeImp.sol:TradeImp",
		// 	{ MarginAccountImp: libMarginAccountImp.address, AMMImp: libAMMImp.address }
		// );
		const perpetual = await createContract("contracts/Perpetual.sol:Perpetual")

		return {
			collateral,
			oracle,
			perpetual
		}
	}

	it("example", async function () {
		const { perpetual } = await createEnviron();
		// await perpetual.deposit(user1, "100000000000000");
		// console.log(await perpetual.callStatic.marginAccount(user1));
	});
});