const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "./utils";

async function deployOracle(accounts: any[]) {
    const oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    
    console.table([
        ["ETH - USD", oracle3.address],
    ])
}

async function main(accounts: any[]) {
    // await deployOracle(accounts);
    
    var makerFactory = await createFactory("PoolCreator");
    var poolCreator = await makerFactory.attach("0xddcB02044Bf4Eb0E312A2278Cca744304005eA6F");
    var wethFactory = await createFactory("WETH9");
    var weth = await wethFactory.attach("0xfA53FD78b5176B4d772194511cC16C02c7F183F9");

    // upgrade
    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    // await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "initial version");
console.log('[1]')
    await poolCreator.addVersion(liquidityPoolTmpl.address, 0, "force settle");
console.log('[2]')

    // await set1(accounts, poolCreator, weth);
    await set2(accounts, poolCreator);
}

async function set1(accounts: any[], poolCreator, weth) {
    // │    0    │  'USD - ETH'  │ '0x45a138C940f91F58014d23F585F226eA1337b2c4' │
    // │    1    │  'BTC - ETH'  │ '0x7a36A2b4a4c4A309E2D6De571533C0A5727dfD2a' │
    const tx = await poolCreator.createLiquidityPool(weth.address, 18 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0x45a138C940f91F58014d23F585F226eA1337b2c4",
        // imr          mmr            operatorfr        lpfr             rebate        penalty        keeper       insur          cap
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx2 = await liquidityPool.createPerpetual("0x7a36A2b4a4c4A309E2D6De571533C0A5727dfD2a",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("40000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    await liquidityPool.runLiquidityPool();

    await liquidityPool.addLiquidity(toWei("0"), { value: toWei("4310") });

    const addresses = [
        ["WETH9", weth.address],
        ["Oracle  'USD - ETH'  ", "0x45a138C940f91F58014d23F585F226eA1337b2c4"],
        ["Oracle  'BTC - ETH'  ", "0x7a36A2b4a4c4A309E2D6De571533C0A5727dfD2a"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
    ]
    console.table(addresses)
    return liquidityPool
}

async function set2(accounts: any[], poolCreator) {
    // │    2    │  'ETH - USD'   │ normal '0xdc1E7859Faea3D54f38b9F3F6e72b8A3828082e5' │
    // │    2    │  'ETH - USD'   │ settle '0x2D982de0Ac0E45920B48FfEDA07CB79ad8e5b118' │
    // │    3    │  'BTC - USD'   │ '0xf3E2BFBfFFcdAC5278F412C2C099b375Ec41ED33' │
    // │    4    │  'DPI - USD'   │ '0x16562D8eA5044CF647Da203B0E24421dDA2C76eF' │
    // │    5    │  'SP500 - USD' │ '0x011BeE38719FB823b7695AE268D8633fc90fF691' │
console.log('[3]')
    var usd = await (await createFactory("CustomERC20")).attach('0x8B2c4Fa78FBA24e4cbB4B0cA7b06A29130317093');
console.log('[4]')

    const tx = await poolCreator.createLiquidityPool(usd.address, 6 /* decimals */, false /* isFastCreationEnabled */, 998 /* nonce */);

console.log('[5]')
    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual("0xdc1E7859Faea3D54f38b9F3F6e72b8A3828082e5", // normal
    // const mtx1 = await liquidityPool.createPerpetual("0x2D982de0Ac0E45920B48FfEDA07CB79ad8e5b118", // settle
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
console.log('[4]')
    const mtx2 = await liquidityPool.createPerpetual("0xf3E2BFBfFFcdAC5278F412C2C099b375Ec41ED33",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx3 = await liquidityPool.createPerpetual("0x16562D8eA5044CF647Da203B0E24421dDA2C76eF",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    const mtx4 = await liquidityPool.createPerpetual("0x011BeE38719FB823b7695AE268D8633fc90fF691",
        [toWei("0.05"), toWei("0.02"), toWei("0.00005"), toWei("0.0005"), toWei("0.5"), toWei("0.01"), toWei("0.1"), toWei("0.2"), toWei("1000000")],
        [toWei("0.0008"), toWei("0.0075"), toWei("0.00525"), toWei("0.005"), toWei("3"), toWei("0.05")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
    )
    await liquidityPool.runLiquidityPool();

    // await usd.mint(accounts[0].address, toWei("12500000"));
    await usd.approve(liquidityPool.address, toWei("2500000"));
    await liquidityPool.addLiquidity(toWei("2500000"));

    const addresses = [
        ["Collateral (USDC)", usd.address],
        ["Oracle  'ETH - USD'  ", "0xdc1E7859Faea3D54f38b9F3F6e72b8A3828082e5"], // normal
        ["Oracle  'ETH - USD'  ", "0x2D982de0Ac0E45920B48FfEDA07CB79ad8e5b118"], // settle
        ["Oracle  'BTC - USD'  ", "0xf3E2BFBfFFcdAC5278F412C2C099b375Ec41ED33"],
        ["Oracle  'DPI - USD'  ", "0x16562D8eA5044CF647Da203B0E24421dDA2C76eF"],
        ["Oracle  'SP500 - USD'", "0x011BeE38719FB823b7695AE268D8633fc90fF691"],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
        ["  PerpetualStorage 2", `@ ${mtx3.blockNumber}`],
        ["  PerpetualStorage 3", `@ ${mtx4.blockNumber}`],
    ]
    console.table(addresses)
    return liquidityPool
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
