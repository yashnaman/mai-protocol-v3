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

	let createFromFactory = async (path, libraries = {}) => {
		const factory = await ethers.getContractFactory(path, { libraries: libraries });
		const deployed = await factory.deploy();
		return deployed;
	}

	let createPerpetual = async () => {
		const libMarginAccountImp = await createFromFactory(
			"contracts/implementation/MarginAccountImp.sol:MarginAccountImp"
		);
		const libAMMImp = await createFromFactory(
			"contracts/implementation/AMMImp.sol:AMMImp", 
			{ MarginAccountImp: libMarginAccountImp.address }
		);
		const libTradeImpFactory = await createFromFactory(
			"contracts/implementation/TradeImp.sol:TradeImp", 
			{ MarginAccountImp: libMarginAccountImp.address, AMMImp: libAMMImp.address }
		);
		return await createFromFactory(
			"contracts/PerpetualWrapper.sol:PerpetualWrapper", 
			{ MarginAccountImp: libMarginAccountImp.address, TradeImp: libTradeImpFactory.address }
		)
	}

	it("example", async function () {
		const perpetual = await createPerpetual();
		await perpetual.deposit(user1, "100000000000000");

		console.log(await perpetual.margin(user1));


	});
});