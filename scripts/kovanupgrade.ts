const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    createFactory,
    createContract,
} from "./utils";

async function deployLibraries() {
    const AMMModule = await createContract("AMMModule"); // 0x7360a5370d5654dc9d2d9e365578c1332b9a82b5
    const CollateralModule = await createContract("CollateralModule") // 0xdea04ead9bce0ba129120c137117504f6dfaf78f
    const OrderModule = await createContract("OrderModule"); // 0xf8781589ae61610af442ffee69d310a092a8d41a
    const PerpetualModule = await createContract("PerpetualModule"); // 0x07315f8eca5c349716a868150f5d1951d310c53e
    const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule }); // 0xbd7bfceb24108a9adbbcd4c57bacdd5194f3be68
    const TradeModule = await createContract("TradeModule", [], { AMMModule, LiquidityPoolModule, CollateralModule, PerpetualModule }); // 0xbe884fecccbed59a32c7185a171223d1c07c446b
    console.table([
        ["AMMModule", AMMModule.address],
        ["CollateralModule", CollateralModule.address],
        ["OrderModule", OrderModule.address],
        ["PerpetualModule", PerpetualModule.address],
        ["LiquidityPoolModule", LiquidityPoolModule.address],
        ["TradeModule", TradeModule.address],
    ])


    // ┌─────────┬───────────────────────┬──────────────────────────────────────────────┐
    // │ (index) │           0           │                      1                       │
    // ├─────────┼───────────────────────┼──────────────────────────────────────────────┤
    // │    0    │      'AMMModule'      │ '0x385E38B34Cdf2E8538Ea9b66E952C61f8784612b' │
    // │    1    │  'CollateralModule'   │ '0x11260394D6F2BF25Cb8e6c439d36136F45E57B1E' │
    // │    2    │     'OrderModule'     │ '0xDCBd383Bc97c0CE5fBC578Aeaaa9202A8C18d2Cc' │
    // │    3    │   'PerpetualModule'   │ '0xCFA0107ccdA59B5475cDeb74F6acb972bF96c6a9' │
    // │    4    │ 'LiquidityPoolModule' │ '0xA1354F77921653eA2df36128bD66510ac7DFD52C' │
    // │    5    │     'TradeModule'     │ '0xe7DA14BE725b1f8331915bd355a308756220d829' │
    // └─────────┴───────────────────────┴──────────────────────────────────────────────┘


    // ┌─────────┬───────────────────────┬──────────────────────────────────────────────┐
    // │ (index) │           0           │                      1                       │
    // ├─────────┼───────────────────────┼──────────────────────────────────────────────┤
    // │    0    │      'AMMModule'      │ '0x18171CA15FfDa3bD536e31F2232d84Ce6d5fa59B' │
    // │    1    │  'CollateralModule'   │ '0x0DCad31Ec25d08B20056f67499666Fa060e10752' │
    // │    2    │     'OrderModule'     │ '0x935e86817A3bf81b182C688Ea36e808264142876' │
    // │    3    │   'PerpetualModule'   │ '0xDf912757e96209A896F3F1Bc4C70fA7e945556be' │
    // │    4    │ 'LiquidityPoolModule' │ '0xada4004290A2a460967D8b6fA01bD616688cE930' │
    // │    5    │     'TradeModule'     │ '0x49Fb1146C06f96aAb7E6C3bE44981aE27d711F3d' │
    // └─────────┴───────────────────────┴──────────────────────────────────────────────┘
}

async function createLiquidityPoolFactory() {
    return await ethers.getContractFactory(
        "LiquidityPool",
        {
            libraries: {
                AMMModule: "0x18171CA15FfDa3bD536e31F2232d84Ce6d5fa59B",
                OrderModule: "0x935e86817A3bf81b182C688Ea36e808264142876",
                LiquidityPoolModule: "0xada4004290A2a460967D8b6fA01bD616688cE930",
                TradeModule: "0x49Fb1146C06f96aAb7E6C3bE44981aE27d711F3d",
            }
        }
    )

}

async function main() {

    // await deployLibraries();

    // var poolCreatorFactory = await createFactory("PoolCreator");
    // var poolCreator = await poolCreatorFactory.attach("0xfa81036567A378C44C5bC13323416aECfeD29D09")

    const LiquidityPool = await createLiquidityPoolFactory();
    var liquidityPoolTmpl = await LiquidityPool.deploy();
    console.log(liquidityPoolTmpl.address);


    // await poolCreator.addVersion(liquidityPoolTmpl.address, 1, "2021/1/18");

    // console.log(await poolCreator.listAvailableVersions(0, 100));
    // console.log(await poolCreator.getLatestVersion());


    // var poolCnt = (await poolCreator.getLiquidityPoolCount()).toString();
    // var pools = await poolCreator.listLiquidityPools(0, poolCnt);

    // var LiquidityPoolFactory = await createLiquidityPoolFactory();
    // for (let i = 0; i < pools.length; i++) {
    //     console.log(pools[i]);
    //     await LiquidityPoolFactory.attach(pools[i])
    // }
}



main().then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });