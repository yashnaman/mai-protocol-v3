const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "./utils";

async function deployOracle(accounts: any[]) {
    const oracle1 = await createContract("OracleWrapper", ["ETH", "USD"]);
    const oracle2 = await createContract("OracleWrapper", ["ETH", "BTC"]);

    const oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    const oracle4 = await createContract("OracleWrapper", ["USD", "BTC"]);
    const oracle5 = await createContract("OracleWrapper", ["USD", "DPI"]);
    const oracle6 = await createContract("OracleWrapper", ["USD", "SP500"]);

    console.table([
        ["USD - ETH", oracle1.address],
        ["BTC - ETH", oracle2.address],
        ["ETH - USD", oracle3.address],
        ["BTC - USD", oracle4.address],
        ["DPI - USD", oracle5.address],
        ["SP500 - USD", oracle6.address],
    ])
}

async function main(accounts: any[]) {
    // await deployOracle(accounts);

    var broker = await createContract("BrokerRelay");
    console.log(broker.address);
    return;

    // common
    var vault = accounts[0];
    var vaultFeeRate = toWei("0.0003");

    var symbol = await createContract("SymbolService", [10000]);

    var weth = await createContract("WETH9");
    var shareTokenTmpl = await createContract("ShareToken");
    var governorTmpl = await createContract("Governor");
    var poolCreator = await createContract(
        "PoolCreator",
        [governorTmpl.address, shareTokenTmpl.address, weth.address, symbol.address, vault.address, vaultFeeRate]
    );
    const addresses = [
        ["poolCreator", poolCreator.address],
        ["symbol", symbol.address]
    ]
    console.table(addresses)

    await symbol.addWhitelistedFactory(poolCreator.address);
    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "initial version");

    const pool1 = await set1(accounts, poolCreator, weth);
    const pool2 = await set2(accounts, poolCreator, weth);

    await reader(accounts, { pool1, pool2 });
}

async function set1(accounts: any[], poolCreator, weth) {
    // │    0    │  'USD - ETH'  │ '0xF34BA0c3c81C88867195143B4368f1cA36AD2571' │
    // │    1    │  'BTC - ETH'  │ '0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82' │
    const tx = await poolCreator.createLiquidityPool(weth.address, false, 998);

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0xF34BA0c3c81C88867195143B4368f1cA36AD2571",
        // imr          mmr            operatorfr        lpfr             rebate        penalty        keeper       insur          cap
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.000010714285714"), toWei("0.000008571428571428"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx2 = await liquidityPool.createPerpetual("0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.3"), toWei("0.24"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    await liquidityPool.runLiquidityPool();

    await liquidityPool.addLiquidity(toWei("0"), { value: toWei("4310") });

    const addresses = [
        ["WETH9", weth.address],
        ["Oracle  'USD - ETH'  ", "0xF34BA0c3c81C88867195143B4368f1cA36AD2571"],
        ["Oracle  'BTC - ETH'  ", "0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
    ]
    console.table(addresses)
    return liquidityPool
}

async function set2(accounts: any[], poolCreator, weth) {
    // │    2    │  'ETH - USD'   │ '0x2dccA2b995651158Fe129Ddd23D658410CEa8254' │
    // │    3    │  'BTC - USD'   │ '0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4' │
    // │    4    │  'DPI - USD'   │ '0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA' │
    // │    5    │  'SP500 - USD' │ '0x37398F5C3D11c11386294Dd3e7464717a10Ffb15' │
    var usd = await createContract("CustomERC20", ["USDC", "USDC", 6]);
    const tx = await poolCreator.createLiquidityPool(usd.address, false, 998);

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0x2dccA2b995651158Fe129Ddd23D658410CEa8254",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("5.25"), toWei("4.2"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx2 = await liquidityPool.createPerpetual("0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("210"), toWei("168"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx3 = await liquidityPool.createPerpetual("0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.75"), toWei("0.6"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx4 = await liquidityPool.createPerpetual("0x37398F5C3D11c11386294Dd3e7464717a10Ffb15",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("27.75"), toWei("22.2"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    await liquidityPool.runLiquidityPool();

    await usd.mint(accounts[0].address, toWei("12500000"));
    await usd.approve(liquidityPool.address, toWei("2500000"));
    await liquidityPool.addLiquidity(toWei("2500000"));

    const addresses = [
        ["Collateral (USDC)", usd.address],
        ["Oracle  'ETH - USD'  ", "0x2dccA2b995651158Fe129Ddd23D658410CEa8254"],
        ["Oracle  'BTC - USD'  ", "0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4"],
        ["Oracle  'DPI - USD'  ", "0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA"],
        ["Oracle  'SP500 - USD'", "0x37398F5C3D11c11386294Dd3e7464717a10Ffb15"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
        ["  PerpetualStorage 2", `@ ${mtx3.blockNumber}`],
        ["  PerpetualStorage 3", `@ ${mtx4.blockNumber}`],
    ]
    console.table(addresses)
    return liquidityPool
}

async function reader(accounts: any[], pools) {
    var reader = await createContract("Reader");
    const addresses = [
        ["Reader", reader.address],
    ]
    console.table(addresses)

    console.log('reader test: pool1')
    console.log(myDump(await reader.callStatic.getLiquidityPoolStorage(pools.pool1.address)))
    console.log('reader test: pool2')
    console.log(myDump(await reader.callStatic.getLiquidityPoolStorage(pools.pool2.address)))

    return { reader }
}

function myDump(o: any, prefix?: string) {
    if (o === null) {
        return 'null'
    }
    if ((typeof o) !== 'object') {
        return o.toString()
    }
    if (ethers.BigNumber.isBigNumber(o)) {
        return o.toString()
    }
    let s = '\n'
    if (!prefix) {
        prefix = ''
    }
    prefix += '  '
    for (let k in o) {
        s += prefix + `${k}: ${myDump(o[k], prefix)}, \n`
    }
    return s
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });