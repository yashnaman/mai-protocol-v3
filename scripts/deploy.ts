const hre = require("hardhat")
const ethers = hre.ethers

import { Deployer, DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo, printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        // ArbRinkeby
        // WETH9: "0xB47e6A5f8b33b3F17603C83a0535A9dcD7E32681",
        // ArbOne
        // WETH9: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        // USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    }
}

const oracleAddresses = {
    // ArbOne
    "ETH - USD": "0x1Cf22B7f84F86c36Cb191BB24993EdA2b191399E",
    "BTC - USD": "0x6ee936BdBD329063E8CE1d13F42eFEf912E85221",
}

const keeperAddresses = [
    // ArbRinkeby
    // '0x276EB779d7Ca51a5F7fba02Bf83d9739dA11e3ba',
    // ArbOne
    '0xDA5F340CB0CD99440E1808506D4cD60706BF2fBF',
    '0x1c990de01d35f3895c9debb8ae85c6a1ade26a17',
]

const guardianAddresses = [
    // ArbRinkeby
    // ArbOne
    '0x45e8e53F5553A3669dAF0Df8971290bad3974f48',
    '0x775CeCa71307700a8B43063DCC15691dB20773e8',
]

function toWei(n) { return hre.ethers.utils.parseEther(n) };
function fromWei(n) { return hre.ethers.utils.formatEther(n); }

async function main(_, deployer, accounts) {
    const upgradeAdmin = "0x93a9182883C1019e1dBEbB5d40C140e7680cd151"
    const vault = "0xa04197E5F7971E7AEf78Cf5Ad2bC65aaC1a967Aa"
    // console.log(accounts);
    // const upgradeAdmin = accounts[0].address;
    // const vault = accounts[1].address;

    const vaultFeeRate = toWei("0.00015");

    // infrastructure
    await deployer.deployOrSkip("Broker")
    await deployer.deployOrSkip("OracleRouterCreator")
    await deployer.deployOrSkip("UniswapV3OracleAdaptorCreator")
    await deployer.deployOrSkip("UniswapV3Tool")
    await deployer.deployOrSkip("InverseStateService")
    // await deployer.deployOrSkip("Reader", deployer.addressOf("InverseStateService"))

    // // test only
    await deployer.deploy("WETH9")
    await deployer.deployOrSkip("CustomERC20", "USDC", "USDC", 6)
    await deployer.deploy("OracleAdaptor", "WETH9", "USDC")

    // upgradeable pool / add whitelist
    await deployer.deployAsUpgradeable("SymbolService", upgradeAdmin)
    const symbolService = await deployer.getDeployedContract("SymbolService")
    await ensureFinished(symbolService.initialize(10000))

    await deployer.deployAsUpgradeable("PoolCreator", upgradeAdmin)
    const poolCreator = await deployer.getDeployedContract("PoolCreator")
    await ensureFinished(poolCreator.initialize(
        deployer.addressOf("SymbolService"),
        vault,
        vaultFeeRate
    ))
    await ensureFinished(symbolService.addWhitelistedFactory(poolCreator.address))
    await deployer.deployOrSkip("Reader", poolCreator.address, deployer.addressOf("InverseStateService"))

    // keeper whitelist
    for (let keeper of keeperAddresses) {
        await poolCreator.addKeeper(keeper)
    }
    for (let guardian of guardianAddresses) {
        await poolCreator.addGuardian(guardian)
    }

    // add version
    const liquidityPool = await deployer.deployOrSkip("LiquidityPool")
    const governor = await deployer.deployOrSkip("LpGovernor")
    await ensureFinished(poolCreator.addVersion(liquidityPool.address, governor.address, 0, "initial version"))

    printInfo("deploying preset2")
    await preset2(deployer, accounts)
    printInfo("deploying preset2 done")
}

async function preset2(deployer, accounts) {
    console.log("WETH9 address", deployer.addressOf("WETH9"));

    // const usd = await deployer.getContractAt("CustomERC20", deployer.addressOf("CustomERC20"))
    const weth = await deployer.getDeployedContract("WETH9");

    const poolCreator = await deployer.getDeployedContract("PoolCreator");
    console.log("creating liquidity pool");
    console.log("poolCreater", poolCreator.address)
    await ensureFinished(poolCreator.createLiquidityPool(
        weth.address,
        18,
        // 6,
        Math.floor(Date.now() / 1000),
        ethers.utils.defaultAbiCoder.encode(["bool", "int256", "uint256", "uint256"], [false, toWei("10000000"), 0, 1])
    ))

    const n = await poolCreator.getLiquidityPoolCount();
    console.log("poolCount", n.toString())
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const liquidityPool = await deployer.getContractAt("LiquidityPool", allLiquidityPools[allLiquidityPools.length - 1]);
    console.log("Create new pool:", liquidityPool.address)

    const oracleAdaptor = await deployer.getContractAt("OracleAdaptor", deployer.addressOf("OracleAdaptor"))
    const provider = ethers.getDefaultProvider(hre.network.config.url);
    const latestBlock = await provider.getBlock("latest");

    const currentTimestamp = latestBlock.timestamp;
    console.log("currentTimestamp", currentTimestamp)
    await ensureFinished(oracleAdaptor.setIndexPrice(hre.ethers.utils.parseUnits("5", "14"), currentTimestamp)); //(1/2000)
    await ensureFinished(oracleAdaptor.setMarkPrice(hre.ethers.utils.parseUnits("5", "14"), currentTimestamp));

    await ensureFinished(liquidityPool.createPerpetual(
        oracleAdaptor.address,
        // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
        [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("0.02"), toWei("0.5"), toWei("3")],
        // alpha           beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev   baseFundingRate
        [toWei("0.00075"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10"), toWei("-0.01")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("-1")],
        [toWei("0.1"), toWei("0.5"), toWei("0.5"), toWei("0.1"), toWei("5"), toWei("1"), toWei("0.1"), toWei("10000000"), toWei("1")]
    ))
    const inverseStateService = await deployer.getDeployedContract("InverseStateService")
    await ensureFinished(inverseStateService.setInverseState(liquidityPool.address, "0", true))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["BTC - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha           beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.00075"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
    //     [toWei("0.1"), toWei("0.5"), toWei("0.5"), toWei("0.1"), toWei("5"), toWei("1"), toWei("0.1"), toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["DPI - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["DOT - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["SP500 - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["TSLA - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["DEFI++ - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    // await ensureFinished(liquidityPool.createPerpetual(
    //     oracleAddresses["DEFI5 - USD"],
    //     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
    //     [toWei("0.04"), toWei("0.03"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
    //     // alpha          beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
    //     [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005"), toWei("10")],
    //     [toWei("0"),      toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
    //     [toWei("0.1"),    toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
    // ))
    await ensureFinished(liquidityPool.runLiquidityPool())

    // await ensureFinished(usd.mint(accounts[0].address, "25000000" + "000000"))
    // await ensureFinished(usd.approve(liquidityPool.address, "25000000" + "000000"))
    // await ensureFinished(liquidityPool.addLiquidity(toWei("25000000")))

    return liquidityPool;
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });


