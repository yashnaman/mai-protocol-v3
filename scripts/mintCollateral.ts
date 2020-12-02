const { ethers } = require("hardhat");

const toWei = ethers.utils.parseEther;
const fromWei = ethers.utils.formatEther;

async function createContract(path, args = [], libraries = {}) {
    const factory = await ethers.getContractFactory(path, { libraries: libraries });
    const deployed = await factory.deploy(...args);
    return deployed;
}

async function main() {

    const factory = await ethers.getContractFactory("CustomERC20");
    // const collateral = await factory.attach("0x010b7D4b32bB7D3cd8F75F01F403Db9b4bC2c671");
    const collateral = await factory.attach("0x9056992a4DCd5e28E6A5FFE4B02af31Ac8d74b37");


    const accounts = await ethers.getSigners();
    const user1 = await accounts[0].getAddress();

    await collateral.mint("0xd595F7c2C071d3FD8f5587931EdF34E92f9ad39F", toWei("1000000000"));

    console.log("done");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });