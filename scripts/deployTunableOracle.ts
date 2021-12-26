const hre = require("hardhat")
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { ensureFinished, printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {}
}

function toWei(n) { return hre.ethers.utils.parseEther(n) };
function fromWei(n) { return hre.ethers.utils.formatEther(n); }

const chainlinks = [
    // arb-rinkeby
    // base, quote, deviation, timeout, chainlink
    // ['BTC',  'ETH', '0.003',  600, '0x6eFd3CCf5c673bd5A7Ea91b414d0307a5bAb9cC1'],
    // ['BTC',  'USD', '0.003',  600, '0x0c9973e7a27d00e656B9f153348dA46CaD70d03d'],
    // ['DAI',  'USD', '0.003',  600, '0xcAE7d280828cf4a0869b26341155E4E9b864C7b2'],
    // ['ETH',  'USD', '0.0005', 600, '0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8'],
    // ['LINK', 'ETH', '0.003',  600, '0x1a658fa1a5747d73D0AD674AF12851F7d74c998e'],
    // ['LINK', 'USD', '0.003',  600, '0x52C9Eb2Cc68555357221CAe1e5f2dD956bC194E5'],
    // ['USDC', 'USD', '0.003',  600, '0xe020609A0C31f4F96dCBB8DF9882218952dD95c4'],
    // ['USDT', 'USD', '0.003',  600, '0xb1Ac85E779d05C2901812d812210F6dE144b2df0'],
]

let chainlinkAdaptors = [
    // arb-rinkeby
    // chainlinkAdaptor, base, quote, deviation, timeout, chainlink
    // ["0x31004084f3B0c6754cE247cb560E6aC4C52EC5b8","BTC","ETH",'0.003',600,"0x6eFd3CCf5c673bd5A7Ea91b414d0307a5bAb9cC1"],
    // ["0x2ef7DD70B7dF600e423678b298C41e2765AF1D55","BTC","USD",'0.003',600,"0x0c9973e7a27d00e656B9f153348dA46CaD70d03d"],
    // ["0xecA5320D63895DA7cf2F5fdd25B7a2a05a78b786","DAI","USD",'0.003',600,"0xcAE7d280828cf4a0869b26341155E4E9b864C7b2"],
    // ["0x46Cac3A645ccb00Aa3fFd949A5bBFE942e844690","ETH","USD",'0.0005',600,"0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8"],
    // ["0xEee3D907BEFfBA58128975424aAaCF8412A998ae","LINK","ETH",'0.003',600,"0x1a658fa1a5747d73D0AD674AF12851F7d74c998e"],
    // ["0x8fd3C5F344F400058Cd0dC859E27571f7355a713","LINK","USD",'0.003',600,"0x52C9Eb2Cc68555357221CAe1e5f2dD956bC194E5"],
    // ["0x7387184Ce69ba00176898D5ad18723dC08b167aF","USDC","USD",'0.003',600,"0xe020609A0C31f4F96dCBB8DF9882218952dD95c4"],
    // ["0x6D17Ab17633AB79162a0b0C7002eCa0772ABe303","USDT","USD",'0.003',600,"0xb1Ac85E779d05C2901812d812210F6dE144b2df0"],
    
    // arb1
    // chainlinkAdaptor, base, quote, deviation, timeout, chainlink
    ["0xBE1e0Fd7942E9A6a59Ea8A039744145cb125AC1A","ETH","USD",'0.015',900,"0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612"],
    ["0xb3fC54ef3A702B0916640688C790ECf622fD9af7","BTC","USD",'0.015',900,"0x6ce185860a4963106506C203335A2910413708e9"],
]

async function deployChainlinkAdaptors(deployer) {
    // deploy (once)
    // const implementation = await deployer.deploy("ChainlinkAdaptor")
    // const beacon = await deployer.deploy("UpgradeableBeacon", implementation.address);

    // add external oracles
    const beacon = await deployer.getContractAt("UpgradeableBeacon", "0xde66ECA1Ed5A881d14A100016B955A59574714a2")
    for (const [base, quote, deviation, timeout, chainlink] of chainlinks) {
        const abi = new ethers.utils.Interface([
            'function initialize(address chainlink_, string memory collateral_, string memory underlyingAsset)',
        ])       
        const data = abi.encodeFunctionData("initialize", [chainlink, quote, base])
        const adaptor = await deployer.deploy("BeaconProxy", beacon.address, data);
        chainlinkAdaptors.push([
            adaptor.address, base, quote, deviation, timeout, chainlink
        ])
    }
    console.log(JSON.stringify(chainlinkAdaptors))
}

async function deployRegister(deployer) {
    const upgradeAdmin = '0x93a9182883C1019e1dBEbB5d40C140e7680cd151'

    // deploy (once)
    // await deployer.deployAsUpgradeable("TunableOracleRegister", upgradeAdmin)

    // init register (once)
    const register = await deployer.getDeployedContract("TunableOracleRegister")
    //    await ensureFinished(register.initialize())
    console.log('beacon implementation =', await register.callStatic.implementation())
}

async function registerChainlink(deployer) {
    const register = await deployer.getDeployedContract("TunableOracleRegister")
    for (const [chainlinkAdaptor, base, quote, deviation, timeout, chainlink] of chainlinkAdaptors) {
        console.log('setting', base, quote)
        await ensureFinished(register.setExternalOracle(chainlinkAdaptor, toWei(deviation), timeout));
    }
}

async function deployTunableOracle(deployer) {
    // arb-rinkeby
    // const liquidityPoolAddress = '0xc32a2dfEe97E2bABc90a2b5e6aef41e789ef2E13'
    // arb1
    const liquidityPoolAddress = '0xaB324146C49B23658E5b3930E641BDBDf089CbAc'

    const register = await deployer.getDeployedContract("TunableOracleRegister")
    for (const [chainlinkAdaptor, base, quote, deviation, timeout, chainlink] of chainlinkAdaptors) {
        console.log('new TunableOracle', base, quote)
        const receipt = await ensureFinished(register.newTunableOracle(liquidityPoolAddress, chainlinkAdaptor));
        console.log('  tx', receipt.transactionHash)
        console.log('  deployed at', receipt.events[0].args['newOracle'])
    }
}

async function deployMultiSetter(deployer) {
    const upgradeAdmin = '0x93a9182883C1019e1dBEbB5d40C140e7680cd151'

    // deploy (once)
    // await deployer.deployAsUpgradeable("MultiTunableOracleSetter", upgradeAdmin)

    // init register (once)
    const setter = await deployer.getDeployedContract("MultiTunableOracleSetter")
    // await ensureFinished(setter.initialize())

    // add oracle
    // arb-rinkeby
    // await ensureFinished(setter.setOracle(0, '0x3741567b65488bE7974C0C10F5c36b821CF3b732'))
    // await ensureFinished(setter.setOracle(1, '0x77e36c7bf78328d3f570aea04b372c9e26b00f4b'))
    // arb1
    await ensureFinished(setter.setOracle(0, '0x9F64F38F18530d70B0caD57d6B929Fa8f371d6c6'))
    await ensureFinished(setter.setOracle(1, '0x78c9014568f8677df0beee444b224e09df519d9e'))
}

async function main(_, deployer, accounts) {
    // 1. deploy chainlink adaptors
    // await deployChainlinkAdaptors(deployer)
    
    // 2. deploy register (once)
    // await deployRegister(deployer)

    // 3. add chainlink into register
    // await registerChainlink(deployer)

    // 4. use Register to deploy some oracles
    // await deployTunableOracle(deployer)

    // 5. deploy multi setter (optional)
    // await deployMultiSetter(deployer)
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });


