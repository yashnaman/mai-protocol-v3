const hre = require("hardhat");
const ether = hre.ethers

import { DeploymentOptions, Deployer, toWei } from './deployer/deployer'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        WETH9: "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
    }
}

async function restorable(job) {
    // detect network
    const deployer = new Deployer(ENV, hre.network.provider)
    await deployer.initialize();
    // main logic
    try {
        await job(deployer)
    } catch (err) {
        console.log("Error occurs when deploying contracts:", err)
    }
    // save deployed
    deployer.finalize()
}

async function main(deployer) {
    const upgradeAdmin = "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a"
    const vault = "0xd69c3820627daC4408CE629730EB8E891F8d5731"
    const vaultFeeRate = toWei("0.00015");

    // infrastructure
    await deployer.deploy("Broker")
    await deployer.deploy("SymbolService", 10000)
    // await deployer.deploy("WETH9")
    await deployer.deploy("CustomERC20", "USDC", "USDC", 6)

    // upgradeable pool / add whitelist
    await deployer.deployAsUpgradeable("PoolCreator", upgradeAdmin)
    const poolCreator = await deployer.getDeployedContract("PoolCreator")
    await poolCreator.initialize(
        deployer.addressOf("WETH9"),
        deployer.addressOf("SymbolService"),
        vault,
        vaultFeeRate,
        vault
    )
    const symbolService = await deployer.getDeployedContract("SymbolService")
    await symbolService.addWhitelistedFactory(poolCreator.address)

    // add version
    const liquidityPool = await deployer.deploy("LiquidityPool")
    const governor = await deployer.deploy("LpGovernor")
    await poolCreator.addVersion(liquidityPool.address, governor.address, 0, "initial version")
}

restorable(main).then(console.log)


