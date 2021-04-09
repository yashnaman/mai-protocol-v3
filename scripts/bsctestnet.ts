const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    setDefaultSigner
} from "./utils";

function toMap(a) {
    const m = {};
    a.forEach(function (e) {
        m[e[0]] = e[1];
    });
    return m;
}

async function deployLibraries() {
    const AMMModule = await createContract("AMMModule");
    const CollateralModule = await createContract("CollateralModule");
    const OrderModule = await createContract("OrderModule");
    const PerpetualModule = await createContract("PerpetualModule");
    const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
    const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule });
    console.table([
        ["AMMModule", AMMModule.address],
        ["CollateralModule", CollateralModule.address],
        ["OrderModule", OrderModule.address],
        ["PerpetualModule", PerpetualModule.address],
        ["LiquidityPoolModule", LiquidityPoolModule.address],
        ["TradeModule", TradeModule.address],
    ])
    
    // 2021/3/4
    // │    0    │      'AMMModule'      │ '0xEfE9a8412b78D3Db7A9f3450F50ac1e0fAa2608b' │
    // │    1    │  'CollateralModule'   │ '0xf7742F893062e8492d1E79027CfFd55983f60a2D' │
    // │    2    │     'OrderModule'     │ '0x95ddD0495022842Fe23484d5835b4679695480dF' │
    // │    3    │   'PerpetualModule'   │ '0x90D7e4610F84B33666DcDCCE0C2b1F7d5bB505EB' │
    // │    4    │ 'LiquidityPoolModule' │ '0x49DD69A10C705BEe36FCD2a2497377fb95c3af2D' │
    // │    5    │     'TradeModule'     │ '0xcEEa08f4FcF7316073d4f635d5cb3B662Fe74cfa' │

    // 2021/4/9
    // │    0    │      'AMMModule'      │ '0x5C2D18091131D4C3C199Ff0E3A89252b6d240B9b' │
    // │    1    │  'CollateralModule'   │ '0xD5a8Cc8A562DF516fD6dcDa528d2133F6685bA9d' │
    // │    2    │     'OrderModule'     │ '0x23A8A7996f07561bB681aF46dD45ACD5bbE6DB4A' │
    // │    3    │   'PerpetualModule'   │ '0xdeD3C98fEA50B866ce967d51ECf29E8Bf3BF11EF' │
    // │    4    │ 'LiquidityPoolModule' │ '0x90b24561Ba9cf98dC6bbA3aF0B19442AE37c1fcf' │
    // │    5    │     'TradeModule'     │ '0xd384807b6005e17430Eb42FB726Ca79B353F8895' │
}

async function createLiquidityPoolFactory() {
    return await ethers.getContractFactory(
        "LiquidityPool",
        {
            libraries: {
                AMMModule: "0x5C2D18091131D4C3C199Ff0E3A89252b6d240B9b",
                OrderModule: "0x23A8A7996f07561bB681aF46dD45ACD5bbE6DB4A",
                LiquidityPoolModule: "0x90b24561Ba9cf98dC6bbA3aF0B19442AE37c1fcf",
                TradeModule: "0xd384807b6005e17430Eb42FB726Ca79B353F8895",
            }
        }
    )
}

async function deployOracle() {
    const oracle3 = await createContract("OracleWrapper", ["USD", "ETH"]);
    const oracle4 = await createContract("OracleWrapper", ["USD", "BTC"]);
    const oracle5 = await createContract("OracleWrapper", ["USD", "DPI"]);
    const oracle6 = await createContract("OracleWrapper", ["USD", "DOT"]);
    const oracle7 = await createContract("OracleWrapper", ["USD", "SP500"]);
    const oracle8 = await createContract("OracleWrapper", ["USD", "TSLA"]);
    const oracleRouterCreator = await createContract("OracleRouterCreator");

    // index printer
    const owner = "0x1a3F275b9Af71D597219899151140a0049DB557b";
    await oracle3.transferOwnership(owner);
    await oracle4.transferOwnership(owner);
    await oracle5.transferOwnership(owner);
    await oracle6.transferOwnership(owner);
    await oracle7.transferOwnership(owner);
    await oracle8.transferOwnership(owner);

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
        ["DOT - USD", oracle6.address],
        ["SP500 - USD", oracle7.address],
        ["TSLA - USD", oracle8.address],
    ];
    console.table(addresses);
    return toMap(addresses);

    // 2021/3/4
    // │    0    │ 'oracleRouterCreator' │ '0x8d44fd514E16c3148cEfA6b759a715d58a11e676' │
    // │    1    │      'USD - ETH'      │ '0xE3fBEF553c5DaCb8ccE6C729DF8D401cA464D53D' │
    // │    2    │      'BTC - ETH'      │ '0x2432a8d74bFC9dE4313a9397b15ff8c91771B7E1' │
    // │    3    │      'ETH - USD'      │ '0x27Ca190b32D8fe7274E84f575feF6E22BDEcA4A5' │
    // │    4    │      'BTC - USD'      │ '0x547b6e5116B6A9167648f1C9d5e5e84ceAC62aae' │
    // │    5    │      'DPI - USD'      │ '0x6fd4C6D4DAA885A948eC8d218e9eaBD638296aFC' │
    // │    6    │      'DOT - USD'      │ '0x34Ee759Dd399F35E63d08A9A5834C148b3fC974F' │
    // │    7    │     'SP500 - USD'     │ '0x07A843FCD4F150700275AD0A5A3A252e50503290' │
    // │    8    │     'TSLA - USD'      │ '0x131a6d689a46c947223937929583a586c32Fb349' │
    // └─────────┴───────────────────────┴──────────────────────────────────────────────┘
    

}

async function main(accounts: any[]) {
    var deployer = { address: "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a" }
    var vault = { address: "0xd69c3820627daC4408CE629730EB8E891F8d5731" }
    var vaultFeeRate = toWei("0.00015");

    // 1. oracle
    // const oracleAddresses = await deployOracle();
    // return
    const oracleAddresses = toMap([
        ["USD - ETH", "0xE3fBEF553c5DaCb8ccE6C729DF8D401cA464D53D"],
        ["BTC - ETH", "0x2432a8d74bFC9dE4313a9397b15ff8c91771B7E1"],
        ["ETH - USD", "0x27Ca190b32D8fe7274E84f575feF6E22BDEcA4A5"],
        ["BTC - USD", "0x547b6e5116B6A9167648f1C9d5e5e84ceAC62aae"],
        ["DPI - USD", "0x6fd4C6D4DAA885A948eC8d218e9eaBD638296aFC"],
        ["DOT - USD", "0x34Ee759Dd399F35E63d08A9A5834C148b3fC974F"],
        ["SP500 - USD", "0x07A843FCD4F150700275AD0A5A3A252e50503290"],
        ["TSLA - USD", "0x131a6d689a46c947223937929583a586c32Fb349"],
    ]);
    
    // 2. libraries
    // await deployLibraries()
    // return

    // 3. factory
    // var symbol = await createContract("SymbolService", [10000])
    // // const symbol = await (await createFactory("SymbolService")).attach('0x63372427A3Bcc8A7d7F04f3A4581A37Cd41f89c4')
    // var poolCreatorTmpl = await createContract("PoolCreator")
    // const admin = '0x1a3F275b9Af71D597219899151140a0049DB557b'
    // var poolCreator = await createContract("TransparentUpgradeableProxy", [
    //     poolCreatorTmpl.address, // logic
    //     admin,
    //     '0x', // data
    //     { gasLimit: 5000000 }
    // ])
    // var broker = await createContract("Broker")
    // const addresses = [
    //     ["poolCreatorTmpl", poolCreatorTmpl.address],
    //     ["poolCreator", `${poolCreator.address} @ ${poolCreator.blockNumber}`],
    //     ["symbol", symbol.address],
    //     ["broker", broker.address],
    // ];
    // console.table(addresses);
    // return
    
    // white list
    const symbol = await (await createFactory("SymbolService")).attach('0x63372427A3Bcc8A7d7F04f3A4581A37Cd41f89c4')
    const poolCreator = await (await createFactory("PoolCreator")).attach('0x6cadfF06B18d9AeF58A974C7073F37B622D660B0')
    var weth = { address: "0xdD7224BDF374e83123Ddda33c38e56F36deb1c4a" }

    // await (await poolCreator.initialize(
    //     weth.address, symbol.address, vault.address, vaultFeeRate, { gasLimit: 5000000 }
    // )).wait()
    // await (await symbol.addWhitelistedFactory(poolCreator.address)).wait();
    // return

    // 4. add version
    // await (await symbol.addWhitelistedFactory(poolCreator.address)).wait();
    // const LiquidityPool = await createLiquidityPoolFactory();
    // var liquidityPoolTmpl = await LiquidityPool.deploy();
    // var governorTmpl = await createContract("LpGovernor");
    // console.table([
    //     ['liquidityPoolTmpl', liquidityPoolTmpl.address],
    //     ["governorTmpl", governorTmpl.address],
    // ]);
    // await (await poolCreator.addVersion(liquidityPoolTmpl.address, governorTmpl.address, 0, "initial version", { gasLimit: 5000000 })).wait();
    // return

    // 5. pools
    // const pool1 = await set1(deployer, poolCreator, oracleAddresses);
    // const pool2 = await set2(deployer, poolCreator, oracleAddresses);

    // 6. reader
    // await deployReader(poolCreator);
}

async function set1(deployer, poolCreator, oracleAddresses) {
    // var eth = await createContract("CustomERC20", ["ETH", "ETH", 18])
    const ETH = "0x5E5016Bb2f20ACA19Cf9324EBbBc02E5A87c69fc"
    var eth = await (await createFactory("CustomERC20")).attach(ETH)
    const tx = await (await poolCreator.createLiquidityPool(
        eth.address,
        18,                             /* decimals */
        Math.floor(Date.now() / 1000),  /* nonce */
        // (isFastCreationEnabled, insuranceFundCap)
        ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [true, toWei("1000")])
    )).wait()

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual(
        oracleAddresses["USD - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper           insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx1.wait()
    const mtx2 = await liquidityPool.createPerpetual(
        oracleAddresses["BTC - ETH"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper           insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.0005"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx2.wait()
    const addresses = [
        ["ETH", ETH],
        ["  LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
    ]
    console.table(addresses)

    console.log('run pool')
    await (await liquidityPool.runLiquidityPool()).wait();

    console.log('add liquidity')
    await eth.mint(deployer.address, toWei("6000"));
    await (await eth.approve(liquidityPool.address, toWei("6000"))).wait();
    await liquidityPool.addLiquidity(toWei("6000"));

    return liquidityPool
}

async function set2(deployer, poolCreator, oracleAddresses) {
    // var usdc = await createContract("CustomERC20", ["USDC", "USDC", 6])
    const USDC = "0xFCd7fFa9c6b88ba3F0D8273C03b9Ade7AFB54A90"
    var usd = await (await createFactory("CustomERC20")).attach(USDC)

    const tx = await (await poolCreator.createLiquidityPool(
        usd.address,
        6,                              /* decimals */
        Math.floor(Date.now() / 1000),  /* nonce */
        // (isFastCreationEnabled, insuranceFundCap)
        ethers.utils.defaultAbiCoder.encode(["bool", "int256"], [true, toWei("1000000")])
    )).wait()

    const n = await poolCreator.getLiquidityPoolCount();
    const allLiquidityPools = await poolCreator.listLiquidityPools(0, n.toString());
    const LiquidityPool = await createLiquidityPoolFactory();
    const liquidityPool = await LiquidityPool.attach(allLiquidityPools[allLiquidityPools.length - 1]);

    const mtx1 = await liquidityPool.createPerpetual(
        oracleAddresses["ETH - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper       insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx1.wait()
    const mtx2 = await liquidityPool.createPerpetual(
        oracleAddresses["BTC - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper       insur          oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx2.wait()
    const mtx3 = await liquidityPool.createPerpetual(
        oracleAddresses["DPI - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx3.wait()
    const mtx4 = await liquidityPool.createPerpetual(
        oracleAddresses["DOT - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx4.wait()
    const mtx5 = await liquidityPool.createPerpetual(
        oracleAddresses["SP500 - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx5.wait()
    const mtx6 = await liquidityPool.createPerpetual(
        oracleAddresses["TSLA - USD"],
        // imr          mmr            operatorfr        lpfr              rebate        penalty          keeper        insur         oi
        [toWei("0.04"), toWei("0.02"), toWei("0.00000"), toWei("0.00055"), toWei("0.2"), toWei("0.005"), toWei("0.5"), toWei("0.25"), toWei("5")],
        // alpha         beta1            beta2             frLimit          lev         maxClose       frFactor
        [toWei("0.0005"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("3"), toWei("0.05"), toWei("0.005")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1"), toWei("1")]
    )
    await mtx6.wait()
    const addresses = [
        ["Collateral (USDC)", USDC],
        ["LiquidityPool", `${liquidityPool.address} @ ${tx.blockNumber}`],
        ["  PerpetualStorage 0", `@ ${mtx1.blockNumber}`],
        ["  PerpetualStorage 1", `@ ${mtx2.blockNumber}`],
        ["  PerpetualStorage 2", `@ ${mtx3.blockNumber}`],
        ["  PerpetualStorage 3", `@ ${mtx4.blockNumber}`],
        ["  PerpetualStorage 4", `@ ${mtx5.blockNumber}`],
        ["  PerpetualStorage 5", `@ ${mtx6.blockNumber}`],
    ]
    console.table(addresses)

    console.log('run pool')
    await (await liquidityPool.runLiquidityPool()).wait();

    console.log('add liquidity')
    await usd.mint(deployer.address, "10000000" + "000000");
    await (await usd.approve(liquidityPool.address, "10000000" + "000000")).wait();
    await liquidityPool.addLiquidity(toWei("10000000"));

    return liquidityPool
}

async function deployReader(poolCreator) {
    var reader = await createContract("Reader", [poolCreator.address]);
    const addresses = [["Reader", reader.address]]
    console.table(addresses)
    return { reader }
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });