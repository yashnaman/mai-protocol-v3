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
        ["ETH / USD", oracle1.address],
        ["ETH / BTC", oracle2.address],
        ["USD / ETH", oracle3.address],
        ["USD / BTC", oracle4.address],
        ["USD / DPI", oracle5.address],
        ["USD / SP500", oracle6.address],
    ])
}

async function main(accounts: any[]) {
    // await deployOracle(accounts);

    // common
    var vault = accounts[0];
    var vaultFeeRate = toWei("0.0003");

    var weth = await createContract("WETH9");
    var shareTokenTmpl = await createContract("ShareToken");
    var governorTmpl = await createContract("Governor");
    var poolCreator = await createContract(
        "PoolCreator",
        [governorTmpl.address, shareTokenTmpl.address, weth.address, vault.address, vaultFeeRate]
    );

    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "initial version");

    const pool1 = await set1(accounts, poolCreator, weth);
    const pool2 = await set2(accounts, poolCreator, weth);

    await reader(accounts, { pool1, pool2 });
    await set1(accounts, poolCreator, weth);
    await set2(accounts, poolCreator, weth);

    const addresses = [
        ["poolCreator", poolCreator.address],
    ]
    console.table(addresses)
}

async function set1(accounts: any[], poolCreator, weth) {
    // │    0    │  'ETH / USD'  │ '0xF34BA0c3c81C88867195143B4368f1cA36AD2571' │
    // │    1    │  'ETH / BTC'  │ '0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82' │
    const tx = await poolCreator.createLiquidityPool(weth.address, 998);

    const n = await poolCreator.liquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createMarket("0xF34BA0c3c81C88867195143B4368f1cA36AD2571",
        // imr          mmr            operatorfr        lpfr             rebate        penalty        keeper       insur
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.01"), toWei("0.0001"), toWei("0.000066"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx2 = await liquidityPool.createMarket("0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.01"), toWei("2"), toWei("1.33"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    await liquidityPool.finalize();

    await liquidityPool.addLiquidity(toWei("0"), { value: toWei("4310") });

    const addresses = [
        ["WETH9", weth.address],
        ["Oracle  'ETH / USD'  ", "0xF34BA0c3c81C88867195143B4368f1cA36AD2571"],
        ["Oracle  'ETH / BTC'  ", "0xDe1421E459E9799e8CeCDd57069329E9ca3ebB82"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  Market 0", `@ ${mtx1.blockNumber}`],
        ["  Market 1", `@ ${mtx2.blockNumber}`],
    ]
    console.table(addresses)
    return liquidityPool
}

async function set2(accounts: any[], poolCreator, weth) {
    // │    2    │  'USD / ETH'  │ '0x2dccA2b995651158Fe129Ddd23D658410CEa8254' │
    // │    3    │  'USD / BTC'  │ '0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4' │
    // │    4    │  'USD / DPI'  │ '0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA' │
    // │    5    │  'USD / SP500' │ '0x37398F5C3D11c11386294Dd3e7464717a10Ffb15' │
    var weth = await createContract("WETH9");
    var usd = await createContract("CustomERC20", ["USD", "USD", 18]);
    const tx = await poolCreator.createLiquidityPool(usd.address, 998);

    const n = await poolCreator.liquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createMarket("0x2dccA2b995651158Fe129Ddd23D658410CEa8254",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.001"), toWei("36"), toWei("24"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx2 = await liquidityPool.createMarket("0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.001"), toWei("1200"), toWei("800"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx3 = await liquidityPool.createMarket("0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.001"), toWei("6"), toWei("4"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    const mtx4 = await liquidityPool.createMarket("0x37398F5C3D11c11386294Dd3e7464717a10Ffb15",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2")],
        [toWei("0.001"), toWei("192"), toWei("128"), toWei("0.005"), toWei("3")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("20000"), toWei("20000"), toWei("1"), toWei("10")],
    )
    await liquidityPool.finalize();

    await usd.mint(accounts[0].address, toWei("12500000"));
    await usd.approve(liquidityPool.address, toWei("2500000"));
    await liquidityPool.addLiquidity(toWei("2500000"));

    const addresses = [
        ["Collateral (USD)", usd.address],
        ["Oracle  'USD / ETH'  ", "0x2dccA2b995651158Fe129Ddd23D658410CEa8254"],
        ["Oracle  'USD / BTC'  ", "0x90aa806A0a2743991CC05aE2206b7d06d6FDbdc4"],
        ["Oracle  'USD / DPI'  ", "0xD9C29A2FbC360cf673dcDB65A87B101f6FD10DEA"],
        ["Oracle  'USD / SP500'", "0x37398F5C3D11c11386294Dd3e7464717a10Ffb15"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  Market 0", `@ ${mtx1.blockNumber}`],
        ["  Market 1", `@ ${mtx2.blockNumber}`],
        ["  Market 2", `@ ${mtx3.blockNumber}`],
        ["  Market 3", `@ ${mtx4.blockNumber}`],
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
    console.log(await reader.callStatic.getLiquidityPoolStorage(pools.pool1.address))
    console.log('reader test: pool2')
    console.log(await reader.callStatic.getLiquidityPoolStorage(pools.pool2.address))

    return { reader }
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });