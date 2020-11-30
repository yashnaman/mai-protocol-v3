const { ethers } = require("hardhat");
import {
    toWei,
    createContract,
    createPerpetualFactory
} from "./utils";

async function main(accounts: any[]) {
    const vault = accounts[0];

    var weth = await createContract("WETH9");
    var ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
    var oracle = await createContract("OracleWrapper", [ctk.address]);
    var lpTokenTemplate = await createContract("ShareToken");
    var govTemplate = await createContract("Governor");
    var maker = await createContract(
        "PerpetualMaker",
        [
            govTemplate.address,
            lpTokenTemplate.address,
            weth.address,
            vault.address,
            toWei("0.001")
        ]
    );
    var perpTemplate = await (await createPerpetualFactory()).deploy();
    await maker.addVersion(perpTemplate.address, 0, "initial version");
    const tx = await maker.createPerpetual(
        oracle.address,
        [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002")],
        [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5")],
        [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
        [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10")],
        998,
    );

    const n = await maker.totalPerpetualCount();
    const allPerpetuals = await maker.listPerpetuals(0, n.toString());
    const perpetualFactory = await createPerpetualFactory();
    const perp = await perpetualFactory.attach(allPerpetuals[allPerpetuals.length - 1]);

    console.log(`test perpetual: ${perp.address} @ ${tx.blockNumber}`)

    const addresses = [
        ["WETH9", weth.address],
        ["Collateral", ctk.address],
        ["Oracle", oracle.address],
        ["PerpetualMaker", maker.address],
        ["Perpetual (test)", perp.address],
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