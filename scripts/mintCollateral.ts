const { ethers } = require("hardhat");

const toWei = ethers.utils.parseEther;
const fromWei = ethers.utils.formatEther;

async function createContract(path, args = [], libraries = {}) {
    const factory = await ethers.getContractFactory(path, { libraries: libraries });
    const deployed = await factory.deploy(...args);
    return deployed;
}

async function main() {

    const factory = await ethers.getContractFactory("contracts/test/CustomERC20.sol:CustomERC20");
    const collateral = await factory.attach("0x12307970883E730472e79Ea5bC7d62a318A0740b");

    const accounts = await ethers.getSigners();
    const user1 = await accounts[0].getAddress();

    await collateral.mint("0x31Ebd457b999Bf99759602f5Ece5AA5033CB56B3", toWei("1000000"));

    console.log("done");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });