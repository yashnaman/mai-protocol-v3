import BigNumber from 'bignumber.js';
import { expect, use } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createLiquidityPoolFactory,
} from '../scripts/utils';
import "./helper";


describe('LiquidityPool', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let vault;
    let ctk;
    let poolCreator;
    let LiquidityPoolFactory;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        vault = accounts[9];
    })

    beforeEach(async () => {
        var weth = await createContract("WETH9");
        var symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
        var lpTokenTemplate = await createContract("LpGovernor");
        var govTemplate = await createContract("TestGovernor");
        poolCreator = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                toWei("0.001")
            ]
        );
        LiquidityPoolFactory = await createLiquidityPoolFactory();
        await symbol.addWhitelistedFactory(poolCreator.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(perpTemplate.address, 0, "initial version");
    });

    it("createPerpetual - fastCreation enabled", async () => {
    })

})

