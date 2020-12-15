const { ethers } = require("hardhat");
import { LiquidityPool } from "../typechain/LiquidityPool";
import {
    toWei,
    createLiquidityPoolFactory
} from "./utils";

async function main(accounts) {

    const user = accounts[0];
    const amount = toWei("10000000")

    // await mint(user, amount)
    // await addLiquidity(user, amount)

    await mint({ address: "0xd595F7c2C071d3FD8f5587931EdF34E92f9ad39F" }, amount)

}

async function addLiquidity(user, amount) {
    {
        const factory = await ethers.getContractFactory("CustomERC20");
        const collateral = await factory.attach("0x97d50C08e9b93e416c2CE4b2E3Ab059012cfdE94")
        await collateral.approve("0xEA7557d345A5f4A927dBbEf04a2A6244d87d27f2", amount);
    }
    {
        const factory = await createLiquidityPoolFactory();
        const liquidityPool = await factory.attach("0xEA7557d345A5f4A927dBbEf04a2A6244d87d27f2");
        await liquidityPool.addLiquidity(amount)
    }
    console.log("add done");
}

async function mint(user, amount) {
    const factory = await ethers.getContractFactory("CustomERC20");
    const collateral = await factory.attach("0x7C9880f0c23C18F072f55353DD4E6fE48463A64D");
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