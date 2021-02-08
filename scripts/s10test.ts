const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory,
    setDefaultSigner,
} from "./utils";

function toMap(a) {
    const m = {};
    a.forEach(function (e) {
        m[e[0]] = e[1];
    });
    return m;
}

async function deployOracle() {
    const oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    const oracle4 = await createContract("OracleWrapper", ["USD", "BTC"]);
    const oracle5 = await createContract("OracleWrapper", ["USD", "DPI"]);
    const oracle6 = await createContract("OracleWrapper", ["USD", "SP500"]);
    const oracleRouterCreator = await createContract("OracleRouterCreator");

    // index printer
    const owner = "0x1a3F275b9Af71D597219899151140a0049DB557b";
    await oracle3.transferOwnership(owner);
    await oracle4.transferOwnership(owner);
    await oracle5.transferOwnership(owner);
    await oracle6.transferOwnership(owner);

    // router: USD/ETH
    let path = [{ oracle: oracle3.address, isInverse: true }];
    let tx = await oracleRouterCreator.createOracleRouter(path);
    await tx.wait();
    const oracle1 = await oracleRouterCreator.routers(await oracleRouterCreator.getPathHash(path));

    // router: BTC/ETH
    path = [{ oracle: oracle3.address, isInverse: true }, { oracle: oracle4.address, isInverse: false }];
    tx = await oracleRouterCreator.createOracleRouter(path);
    await tx.wait();
    const oracle2 = await oracleRouterCreator.routers(await oracleRouterCreator.getPathHash(path));

    const addresses = [
        ["oracleRouterCreator", oracleRouterCreator.address],
        ["USD - ETH", oracle1],
        ["BTC - ETH", oracle2],
        ["ETH - USD", oracle3.address],
        ["BTC - USD", oracle4.address],
        ["DPI - USD", oracle5.address],
        ["SP500 - USD", oracle6.address],
    ];
    console.table(addresses);
    return toMap(addresses);
}

async function main(accounts: any[]) {
    var vault = accounts[0];
    var vaultFeeRate = toWei("0.00015");

    // 1. oracle
    // const oracleAddresses = await deployOracle();
    const oracleAddresses = toMap([
        ["USD - ETH", "0xB0a56FFFE96de53Da39EB2d494461dD19d99d5c8"],
        ["BTC - ETH", "0x28A66eD4676711fFe58F5aC6CaFb959E642bab66"],
        ["ETH - USD", "0xbb05666820137B3B1344fE6802830515c015Dd4F"],
        ["BTC - USD", "0xc880Bd54e8D5D38505892e8a8656B55B6D7a1Ef6"],
        ["DPI - USD", "0x34E3b056Fd52BdE8a82c047D51751CE431e79E6F"],
        ["SP500 - USD", "0xdf1Cea3495346aDECB749873bB567B6e7083cf0c"],
    ]);

    // 2. factory
    var symbol = await createContract("SymbolService", [10000]);
    var wethFactory = await createFactory("WETH9");
    var weth = await wethFactory.attach("0xfA53FD78b5176B4d772194511cC16C02c7F183F9");
    var shareTokenTmpl = await createContract("LpGovernor");
    var governorTmpl = await createContract("LpGovernor");
    var poolCreator = await createContract(
        "PoolCreator",
        [governorTmpl.address, shareTokenTmpl.address, weth.address, symbol.address, vault.address, vaultFeeRate]);
    var broker = await createContract("Broker");
    const addresses = [
        ["governor", governorTmpl.address],
        ["shareTokenTmpl", shareTokenTmpl.address],
        ["poolCreator", poolCreator.address],
        ["symbol", symbol.address],
        ["broker", broker.address],
    ];
    console.table(addresses);

    await symbol.addWhitelistedFactory(poolCreator.address);
    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "initial version");

    const pool1 = await set1(accounts, poolCreator, weth, oracleAddresses);
    const pool2 = await set2(accounts, poolCreator, weth, oracleAddresses);

    await reader(accounts, { pool1, pool2 });
}

async function set1(accounts: any[], poolCreator, weth, oracleAddresses) {
    const tx = await poolCreator.createLiquidityPool(weth.address, 18 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);
    await tx.wait();

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual(
        oracleAddresses["USD - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper           insur         cap
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("1000")],
        // alpha          beta1            beta2             fr              lev         max close
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    await mtx1.wait();

    const mtx2 = await liquidityPool.createPerpetual(
        oracleAddresses["BTC - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper           insur         cap
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("1000")],
        // alpha          beta1            beta2             fr              lev         max close
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    await mtx2.wait();
    await liquidityPool.runLiquidityPool();

    await liquidityPool.addLiquidity(toWei("0"), { value: toWei("6600") });

    const addresses = [
        ["WETH9", weth.address],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["    PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["    PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
    ];
    console.table(addresses);
    return liquidityPool;
}

async function set2(accounts: any[], poolCreator, weth, oracleAddresses) {
    var usd = await (await createFactory("CustomERC20")).attach("0x8B2c4Fa78FBA24e4cbB4B0cA7b06A29130317093");

    const tx = await poolCreator.createLiquidityPool(usd.address, 6 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);
    await tx.wait();

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual(
        oracleAddresses["ETH - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         cap
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("1000000")],
        // alpha         beta1            beta2             fr              lev         max close
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    const mtx2 = await liquidityPool.createPerpetual(
        oracleAddresses["BTC - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         cap
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("1000000")],
        // alpha         beta1            beta2             fr              lev         max close
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    const mtx3 = await liquidityPool.createPerpetual(
        oracleAddresses["DPI - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         cap
        [toWei("0.10"), toWei("0.05"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("1000000")],
        // alpha         beta1            beta2             fr              lev         max close
        [toWei("0.003"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    const mtx4 = await liquidityPool.createPerpetual(
        oracleAddresses["SP500 - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         cap
        [toWei("0.10"), toWei("0.05"), toWei("0.00000"), toWei("0.00055"), toWei("0.4"), toWei("0.005"), toWei("0.1"), toWei("0.25"), toWei("1000000")],
        // alpha         beta1            beta2             fr              lev         max close
        [toWei("0.003"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")]
    );
    await liquidityPool.runLiquidityPool();

    await usd.mint(accounts[0].address, "2500000" + "000000");
    await usd.approve(liquidityPool.address, "2500000" + "000000");
    await liquidityPool.addLiquidity(toWei("2500000"));

    const addresses = [
        ["Collateral (USDC)", usd.address],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["    PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["    PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
        ["    PerpetualStorage 2", `@ ${mtx3.blockNumber}`],
        ["    PerpetualStorage 3", `@ ${mtx4.blockNumber}`],
    ];
    console.table(addresses);
    return liquidityPool;
}

async function reader(accounts: any[], pools) {
    var reader = await createContract("Reader");
    const addresses = [["Reader", reader.address]];
    console.table(addresses);

    console.log("reader test: pool1");
    console.log(myDump(await reader.callStatic.getLiquidityPoolStorage(pools.pool1.address)));
    console.log("reader test: pool2");
    console.log(myDump(await reader.callStatic.getLiquidityPoolStorage(pools.pool2.address)));

    return { reader };
}

function myDump(o: any, prefix?: string) {
    if (o === null) {
        return "null";
    }
    if (typeof o !== "object") {
        return o.toString();
    }
    if (ethers.BigNumber.isBigNumber(o)) {
        return o.toString();
    }
    let s = "\n";
    if (!prefix) {
        prefix = "";
    }
    // prefix += '    '
    // for (let k in o) {
    //         s += prefix + `${k}: ${myDump(o[k], prefix)}, \n`
    // }
    return s;
}

ethers
    .getSigners()
    .then((accounts) => main(accounts))
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
