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
import { BrokerRelay } from "../typechain/BrokerRelay";

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
        let testOrder;
        let testRelay;
        let ctk;
        let oracle;

        beforeEach(async () => {
            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];


            testRelay = await createContract("BrokerRelay");
            ctk = await createContract("CustomERC20", ["collateral", "CTK", 18]);
            oracle = await createContract("OracleWrapper", ["ctk", "ctk"]);
            const AMMModule = await createContract("AMMModule");
            const CollateralModule = await createContract("CollateralModule")
            const OrderModule = await createContract("OrderModule");
            const PerpetualModule = await createContract("PerpetualModule");
            const LiquidityPoolModule = await createContract("LiquidityPoolModule", [], { CollateralModule, AMMModule, PerpetualModule });
            const TradeModule = await createContract("TradeModule", [], { AMMModule, CollateralModule, PerpetualModule, LiquidityPoolModule });
            testOrder = await createContract("TestOrder", [], { OrderModule });
            testTrade = await createContract("TestTrade", [], {
                AMMModule,
                CollateralModule,
                OrderModule,
                PerpetualModule,
                LiquidityPoolModule,
                TradeModule,
            });
            await testTrade.createPerpetual(
                oracle.address,
                // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
                [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0007"), toWei("0"), toWei("0.005"), toWei("1"), toWei("0.0001"), toWei("10000")],
                [toWei("0.001"), toWei("100"), toWei("90"), toWei("0.005"), toWei("5")],
            )
            await testTrade.setOperator(user0.address)
            await testTrade.setVault(user4.address, toWei("0.0002"))
            await testTrade.setCollateralToken(ctk.address, 18);
            await ctk.mint(testTrade.address, toWei("10000000000"));
        })


        it('broker', async () => {

            await testTrade.setState(0, 2);
            await testTrade.setTotalCollateral(0, toWei("10000000000"));
            await testTrade.setUnitAccumulativeFunding(0, toWei("9.9059375"))

            let now = Math.floor(Date.now() / 1000);
            await oracle.setMarkPrice(toWei("6965"), now);
            await oracle.setIndexPrice(toWei("7000"), now);

            await testTrade.setMarginAccount(0, user1.address, toWei('7698.86'), toWei('2.3'));
            await testTrade.setMarginAccount(0, testTrade.address, toWei('83941.29865625'), toWei('2.3'));

            const order = {
                trader: user1.address, // trader
                broker: testRelay.address, // broker
                relayer: user0.address, // relayer
                // broker: user0.address,
                // relayer: user0.address,
                liquidityPool: testTrade.address, // liquidityPool
                referrer: "0x0000000000000000000000000000000000000000", // referrer
                minTradeAmount: toWei("0.1"),
                amount: toWei("-0.5"),
                limitPrice: toWei("0"),
                triggerPrice: toWei("0"),
                chainID: 31337,
                expiredAt: now + 10000,
                perpetualIndex: 0,
                brokerFeeLimit: 20,  // 20 gwei
                flags: 0x00000000,
                salt: 123456,
            };
            var orderHash = await testOrder.orderHash(order);
            const sig = await user1.signMessage(ethers.utils.arrayify(orderHash));
            var { r, s, v } = ethers.utils.splitSignature(sig);
            var compressed = await testOrder.compress(order, r, s, v, 0);
            expect(await testOrder.getSigner(order, sig)).to.equal(user1.address);
            await testRelay.batchTrade([compressed], [toWei("-0.5")], [toWei("0")]);
            // await testTrade.brokerTrade(compressed, toWei("-0.5"));

            var { cash } = await testTrade.callStatic.getMarginAccount(0, user1.address);
            expect(cash).approximateBigNumber(toWei("11178.8766232"));
        })
    })
})