import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    fromBytes32,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

import "./helper";

describe('TradeModule1', () => {
    let accounts;

    before(async () => {
        accounts = await getAccounts();
    })

    describe('basic', async () => {
        let user0;
        let user1;
        let user2;
        let user3;
        let user4;
        let user5;
        let none = "0x0000000000000000000000000000000000000000";

        let testTrade;
        let ctk;
        let oracle;
        let mocker;

        beforeEach(async () => {
            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];

            ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            oracle = await createContract("OracleWrapper", ["ctk", "ctk"]);
            const AMMModule = await createContract("AMMModule");
            const CollateralModule = await createContract("CollateralModule")
            const PerpetualModule = await createContract("PerpetualModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });

            const MockAMMModule = await createContract("MockAMMModule");
            const TradeModule = await createContract("TradeModule", [], { AMMModule: MockAMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
            testTrade = await createContract("TestTrade", [], {
                PerpetualModule,
                CollateralModule,
                LiquidityPoolModule,
                TradeModule,
            });
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0"), toWei("1000")],
                [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.2")],
            )
            await testTrade.setOperator(user0.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))
            await testTrade.setCollateralToken(ctk.address, 18);
            await ctk.mint(testTrade.address, toWei("10000000000"));

            mocker = await createContract("MockAMMPriceEntries");
            await testTrade.setGovernor(mocker.address);
            await testTrade.setState(0, 2);
        })

        it("liquidateByAMM", async () => {
            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(toWei("1000"), now);
            await oracle.setIndexPrice(toWei("1000"), now);
            await testTrade.updatePrice(now);

            await mocker.setPrice(toWei("1000"));
            await ctk.mint(testTrade.address, toWei("1000"));
            await testTrade.setTotalCollateral(0, toWei("1000"));

            await testTrade.setMarginAccount(0, user2.address, toWei("5000"), toWei("0"));

            await testTrade.setMarginAccount(0, user1.address, toWei("-950"), toWei("1")); // 100 / 50
            await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

            await expect(testTrade.liquidateByAMM(0, user2.address, user1.address)).to.be.revertedWith("trader is safe");

            await testTrade.setMarginAccount(0, user1.address, toWei("-960"), toWei("1")); // 100 / 40
            await testTrade.setMarginAccount(0, testTrade.address, toWei("10000"), toWei("0"));

            await testTrade.liquidateByAMM(0, user2.address, user1.address);
            var { cash, position } = await testTrade.getMarginAccount(0, user1.address);
            expect(cash).to.equal(toWei("34")) // 1000 + fee = 0.001 // 1000 * 1 * 0.005 = 5
            expect(position).to.equal(toWei("0"))
            expect(await ctk.balanceOf(user2.address)).to.equal(toWei("1"));


        })
    })
})