const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory,
    fromWei
} from "./utils";

async function deployOracle(signer, addresses) {
    const oracle1 = await createContract("OracleWrapper", ["ETH", "USD"]);
    const oracle2 = await createContract("OracleWrapper", ["ETH", "BTC"]);

    const oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    const oracle4 = await createContract("OracleWrapper", ["USD", "BTC"]);
    const oracle5 = await createContract("OracleWrapper", ["USD", "DPI"]);
    const oracle6 = await createContract("OracleWrapper", ["USD", "SP500"]);

    addresses = addresses.concat([
        ["USD - ETH", oracle1.address],
        ["BTC - ETH", oracle2.address],
        ["ETH - USD", oracle3.address],
        ["BTC - USD", oracle4.address],
        ["DPI - USD", oracle5.address],
        ["SP500 - USD", oracle6.address],
    ])
    return { oracle1, oracle2, oracle3, oracle4, oracle5, oracle6 }
}

async function deployBrokerRelay(signer, addresses) {
    var brokerRelay = await createContract("Broker", signer = signer);
    addresses = addresses.concat([
        ["Broker", brokerRelay.address],
    ])
    return { brokerRelay }
}

async function deployInfrastructures(signer, addresses) {
    var symbol = await createContract("SymbolService", [10000]);
    var weth = await createContract("WETH9");
    addresses = addresses.concat([
        ["Symbol", symbol.address],
        ["WETH", weth.address],
    ])
    return { symbol, weth }
}

async function deployPoolCreator(signer, weth, symbol, vault, vaultFeeRate, addresses) {
    var shareTokenTmpl = await createContract("ShareToken");
    var governorTmpl = await createContract("TestGovernor");
    var poolCreator = await createContract(
        "PoolCreator",
        [governorTmpl.address, shareTokenTmpl.address, weth.address, symbol.address, vault.address, vaultFeeRate]
    );
    await symbol.addWhitelistedFactory(poolCreator.address);
    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "initial version");

    addresses = addresses.concat([
        ["ShareToken Implementation", shareTokenTmpl.address],
        ["Governor Implementation", governorTmpl.address],
        ["PoolCreator", poolCreator.address],
        ["Vault", vault.address],
        ["VaultFeeRate", fromWei(vaultFeeRate)],
    ])
    return { poolCreator }
}

async function main(accounts) {

    var deployer = { address: "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a", private: "d961926e05ae51949465139b95d91faf028de329278fa5db7462076dd4a245f4" }
    var vault = { address: "0xd69c3820627daC4408CE629730EB8E891F8d5731", private: "55ebe4b701c11e6a04b5d77bb25276f090a6fd03a88c6d97ea85e40cd2a3926e" }
    var vaultFeeRate = toWei("0.0003");

    const provider = new ethers.providers.JsonRpcProvider("https://kovan2.arbitrum.io/rpc");
    const signer = new ethers.Wallet(deployer.private, provider)

    let addresses = []
    // let { oracle1, oracle2, oracle3, oracle4, oracle5, oracle6 } = await deployOracle(signer, addresses);
    let { brokerRelay } = await deployBrokerRelay(signer, addresses);
    // let { symbol, weth } = await deployInfrastructures(signer, addresses);
    // let { poolCreator } = await deployPoolCreator(signer, addresses);





    // const pool1 = await set1(accounts, poolCreator, weth);
    // const pool2 = await set2(accounts, poolCreator, weth);

    // await reader(accounts, { pool1, pool2 });
}

async function set1(accounts: any[], poolCreator, weth) {
    // │    0    │  'USD - ETH'  │ '0x57B3e8836681937bcdC40044B1FF5b574664f321' │
    // │    1    │  'BTC - ETH'  │ '0x16A35eDa33e28d75da662E91a808D674c5E80c29' │
    const tx = await poolCreator.createLiquidityPool(weth.address, 18 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);
    await tx.wait()

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0x57B3e8836681937bcdC40044B1FF5b574664f321",
        // imr          mmr            operatorfr        lpfr             rebate        penalty        keeper       insur          cap
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx2 = await liquidityPool.createPerpetual("0x16A35eDa33e28d75da662E91a808D674c5E80c29",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    await liquidityPool.runLiquidityPool();

    await liquidityPool.addLiquidity(toWei("0"), { value: toWei("2500") });

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
    // │    2    │  'ETH - USD'   │ '0x6B61774d291AC46444c2a32D91621532b22A301C' │
    // │    3    │  'BTC - USD'   │ '0xa920a1d31aa3cE77C557a9106a056fE8d99bB75c' │
    // │    4    │  'DPI - USD'   │ '0x406e84F1ad2e0806A6cbbf0178beFF9C6Cb8fDA3' │
    // │    5    │  'SP500 - USD' │ '0x37398F5C3D11c11386294Dd3e7464717a10Ffb15' │
    var usd = await (await createFactory("CustomERC20")).attach('0x8B2c4Fa78FBA24e4cbB4B0cA7b06A29130317093');

    const tx = await poolCreator.createLiquidityPool(usd.address, 6 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);
    await tx.wait()

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0x6B61774d291AC46444c2a32D91621532b22A301C",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx2 = await liquidityPool.createPerpetual("0xa920a1d31aa3cE77C557a9106a056fE8d99bB75c",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx3 = await liquidityPool.createPerpetual("0x406e84F1ad2e0806A6cbbf0178beFF9C6Cb8fDA3",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx4 = await liquidityPool.createPerpetual("0x4327b88af616B31E48c745613f1BACa347f7630a",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    await liquidityPool.runLiquidityPool();

    await usd.mint(accounts[0].address, "2500000" + "000000");
    await usd.approve(liquidityPool.address, "2500000" + "000000");
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