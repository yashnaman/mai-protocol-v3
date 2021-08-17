const hre = require("hardhat")
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { readOnlyEnviron } from './deployer/environ'
import { printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {}
}

async function main(_, deployer, accounts) {
    // 1. deploy
    // const implementation = deployer.deploy("Contract u want to deploy")
    // const beacon = await deployer.deploy("UpgradeableBeacon", implementation.address);
    // const proxy = await deployer.deploy("BeaconProxy", beacon.address, "0x");

    // 2. upgrade
    // const beacon = await deployer.getContractAt("UpgradeableBeacon", "Deployed UpgradeableBeacon")
    // await beacon.upgradeTo("Contract u want to upgrade to")
}

ethers.getSigners()
    .then(accounts => readOnlyEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });


