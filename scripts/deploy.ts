const hre = require("hardhat")
const ethers = hre.ethers

import { Deployer, DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo, printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        WETH9: "0xfA53FD78b5176B4d772194511cC16C02c7F183F9",
    }
}

const oracleAddresses = {
    "USD - ETH": "0xB0a56FFFE96de53Da39EB2d494461dD19d99d5c8",
    "BTC - ETH": "0x28A66eD4676711fFe58F5aC6CaFb959E642bab66",
    "ETH - USD": "0xbb05666820137B3B1344fE6802830515c015Dd4F",
    "BTC - USD": "0xc880Bd54e8D5D38505892e8a8656B55B6D7a1Ef6",
    "DPI - USD": "0x34E3b056Fd52BdE8a82c047D51751CE431e79E6F",
    "SP500 - USD": "0xdf1Cea3495346aDECB749873bB567B6e7083cf0c",
}

function toWei(n) { return hre.ethers.utils.parseEther(n) };
function fromWei(n) { return hre.ethers.utils.formatEther(n); }

async function main(_, deployer, accounts) {
    const upgradeAdmin = "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a"
    const vault = "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a"
    const vaultFeeRate = toWei("0.00015");

    // infrastructure
    await deployer.deployOrSkip("Broker")
    await deployer.deployOrSkip("SymbolService", 10000)
    // await deployer.deploy("WETH9")
    await deployer.deployOrSkip("CustomERC20", "USDC", "USDC", 6)

    // upgradeable pool / add whitelist 
    const tx = await deployer.deployAsUpgradeable("PoolCreator", upgradeAdmin)
    const poolCreator = await deployer.getDeployedContract("PoolCreator")
    await ensureFinished(poolCreator.initialize(
        deployer.addressOf("SymbolService"),
        vault,
        vaultFeeRate,
        vault
    ))
    const symbolService = await deployer.getDeployedContract("SymbolService")
    await ensureFinished(symbolService.addWhitelistedFactory(poolCreator.address))

    // add version
    const liquidityPool = await deployer.deployOrSkip("LiquidityPool")
    const governor = await deployer.deployOrSkip("LpGovernor")
    await ensureFinished(poolCreator.addVersion(liquidityPool.address, governor.address, 0, "initial version"))

    // printInfo("deploying preset1")
    // await preset1(deployer, accounts)
    // printInfo("deploying preset1 done")

    // printInfo("deploying preset2")
    // await preset2(deployer, accounts)
    // printInfo("deploying preset2 done")
}


async function preset1(deployer, accounts) {

    const poolCreator = await deployer.getDeployedContract("PoolCreator")
    await ensureFinished(poolCreator.createLiquidityPool(
        deployer.addressOf("WETH9"),
        18,
        991,
        ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")])
    ))
    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const liquidityPool = await deployer.getContractAt("LiquidityPool", allLiquidityPools[allLiquidityPools.length - 1]);

    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["USD - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper           insur          oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))
    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["BTC - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper           insur          oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))
    await ensureFinished(liquidityPool.runLiquidityPool())
    await ensureFinished(liquidityPool.addLiquidity(toWei("0"), { value: toWei("6600") }));
    return liquidityPool
}

async function preset2(deployer, accounts) {
    const usd = await deployer.getContractAt("CustomERC20", "0x8B2c4Fa78FBA24e4cbB4B0cA7b06A29130317093")
    const poolCreator = await deployer.getDeployedContract("PoolCreator")

    await ensureFinished(poolCreator.createLiquidityPool(
        usd.address,
        6,
        998,
        ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [false, toWei("1000000")])
    ))

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const liquidityPool = await deployer.getContractAt("LiquidityPool", allLiquidityPools[allLiquidityPools.length - 1]);

    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["ETH - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper        insur          oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))
    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["BTC - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper        insur          oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))
    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["DPI - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper        insur          oi
        [toWei("0.10"), toWei("0.05"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))
    await ensureFinished(liquidityPool.createPerpetual(
        oracleAddresses["SP500 - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty         keeper        insur          oi
        [toWei("0.10"), toWei("0.05"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    ))

    await ensureFinished(liquidityPool.runLiquidityPool())

    await ensureFinished(usd.mint(accounts[0].address, "2500000" + "000000"))
    await ensureFinished(usd.approve(liquidityPool.address, "2500000" + "000000"))
    await ensureFinished(liquidityPool.addLiquidity(toWei("2500000")))

    return liquidityPool;
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });


