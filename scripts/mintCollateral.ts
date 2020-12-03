const { ethers } = require("hardhat");
import { Perpetual } from "../typechain/Perpetual";
import {
    toWei,
    createPerpetualFactory
} from "./utils";

async function main(accounts) {

    const user = accounts[0];
    const amount = toWei("10000000")

    await mint(user, amount)
    await addLiquidity(user, amount)

}

async function addLiquidity(user, amount) {
    {
        const factory = await ethers.getContractFactory("CustomERC20");
        const collateral = await factory.attach("0x97d50C08e9b93e416c2CE4b2E3Ab059012cfdE94")
        await collateral.approve("0xEA7557d345A5f4A927dBbEf04a2A6244d87d27f2", amount);
    }
    {
        const factory = await createPerpetualFactory();
        const perpetual = await factory.attach("0xEA7557d345A5f4A927dBbEf04a2A6244d87d27f2");
        await perpetual.addLiquidity(amount)
    }
    console.log("add done");
}

async function mint(user, amount) {
    const factory = await ethers.getContractFactory("CustomERC20");
    const collateral = await factory.attach("0x97d50C08e9b93e416c2CE4b2E3Ab059012cfdE94");
    await collateral.mint(user.address, amount);
    console.log("mint done");
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });