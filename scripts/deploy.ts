const { ethers } = require("hardhat");
import {
    toWei,
    createFactory,
    createContract,
    createSharedLiquidityPoolFactory
} from "./utils";

async function main(accounts: any[]) {
    const vault = accounts[0];

    var weth = await createContract("WETH9");
    var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
    var lpTokenTemplate = await createContract("ShareToken");
    var govTemplate = await createContract("Governor");
    var poolCreator = await createContract(
        "PoolCreator",
        [
            govTemplate.address,
            lpTokenTemplate.address,
            weth.address,
            vault.address,
            toWei("0.001")
        ]
    );
    const SharedLiquidityPool = await createSharedLiquidityPoolFactory();
    var perpTemplate = await SharedLiquidityPool.deploy();
    await poolCreator.addVersion(perpTemplate.address, 0, "initial version");
    const tx = await poolCreator.createSharedLiquidityPool(ctk.address, 998);

    const n = await poolCreator.sharedLiquidityPoolCount();
    const allSharedLiquidityPools = await poolCreator.listSharedLiquidityPools(0, n.toString());
    const sharedLiquidityPool = await SharedLiquidityPool.attach(allSharedLiquidityPools[allSharedLiquidityPools.length - 1]);

    var oracle = await createContract("OracleWrapper", [ctk.address]);
    await sharedLiquidityPool.createMarket(oracle.address,
        [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
        [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
    )
    await sharedLiquidityPool.createMarket(oracle.address,
        [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
        [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
    )
    await sharedLiquidityPool.createMarket(oracle.address,
        [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
        [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
    )
    await sharedLiquidityPool.createMarket(oracle.address,
        [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5")],
        [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
    )
    await sharedLiquidityPool.finalize();

    var broker = await createContract("BrokerRelay")

    const addresses = [
        ["WETH9", weth.address],
        ["Collateral", ctk.address],
        ["Oracle", oracle.address],
        ["PoolCreator", poolCreator.address],
        ["BrokerRelay", broker.address],
        ["SharedLiquidityPool (test)", `${sharedLiquidityPool.address} @ ${tx.blockNumber}`],
    ]

    console.table(addresses)
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });