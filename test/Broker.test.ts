import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createLiquidityPoolFactory,
} from '../scripts/utils';
import { TypedDataUtils } from 'ethers-eip712'
import {
    ecsign
} from 'ethereumjs-util'


describe('Broker', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let vault;
    let ctk;
    let oracle;
    let poolCreator;
    let LiquidityPoolFactory;
    let liquidityPool;
    let broker;
    let testOrder;

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
        var govTemplate = await createContract("LpGovernor");
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

        LiquidityPoolFactory = await createLiquidityPoolFactory("LiquidityPoolRelayable");
        await symbol.addWhitelistedFactory(poolCreator.address);
        var perpTemplate = await LiquidityPoolFactory.deploy();
        await poolCreator.addVersion(perpTemplate.address, 0, "initial version");

        const liquidityPoolAddr = await poolCreator.callStatic.createLiquidityPool(ctk.address, 18, false, 998);
        await poolCreator.createLiquidityPool(ctk.address, 18, false, 998);
        liquidityPool = await LiquidityPoolFactory.attach(liquidityPoolAddr);

        oracle = await createContract("OracleWrapper", ["USD", "ETH"]);
        await liquidityPool.createPerpetual(
            oracle.address,
            // imr         mmr            operatorfr      lpfr            rebate        penalty        keeper       insur
            [toWei("0.1"), toWei("0.05"), toWei("0.0001"), toWei("0.0008"), toWei("0"), toWei("0.005"), toWei("2"), toWei("0.0001"), toWei("10000")],
            [toWei("0.001"), toWei("0.014285714285714285"), toWei("0.012857142857142857"), toWei("0.005"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("1"), toWei("1"), toWei("1"), toWei("1"), toWei("10"), toWei("1")],
        )
        await liquidityPool.runLiquidityPool();

        broker = await createContract("Broker");

        const OrderModule = await createContract("OrderModule");
        testOrder = await createContract("TestOrder", [], { OrderModule });
    });

    it('broker', async () => {
        let now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("1000"), now);
        await oracle.setIndexPrice(toWei("1000"), now);

        await ctk.mint(user1.address, toWei("10000"))
        await ctk.mint(user2.address, toWei("10000"))
        await ctk.connect(user1).approve(liquidityPool.address, toWei("10000"))
        await ctk.connect(user2).approve(liquidityPool.address, toWei("10000"))
        await liquidityPool.connect(user1).deposit(0, user1.address, toWei("10000"));
        await liquidityPool.connect(user2).addLiquidity(toWei("10000"));

        const order = {
            trader: user1.address, // trader
            broker: broker.address, // broker
            relayer: user0.address, // relayer
            // broker: user0.address,
            // relayer: user0.address,
            liquidityPool: liquidityPool.address, // liquidityPool
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
        await broker.batchTrade([compressed], [toWei("-0.5")], [toWei("0")]);
        // await liquidityPool.brokerTrade(compressed, toWei("-0.5"));

        var { position } = await liquidityPool.getMarginAccount(0, user1.address);
        expect(position).to.equal(toWei("-0.5"));
    })

    it('broker - cancel', async () => {
        let now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("1000"), now);
        await oracle.setIndexPrice(toWei("1000"), now);

        await ctk.mint(user1.address, toWei("10000"))
        await ctk.mint(user2.address, toWei("10000"))
        await ctk.connect(user1).approve(liquidityPool.address, toWei("10000"))
        await ctk.connect(user2).approve(liquidityPool.address, toWei("10000"))
        await liquidityPool.connect(user1).deposit(0, user1.address, toWei("10000"));
        await liquidityPool.connect(user2).addLiquidity(toWei("10000"));

        const order = {
            trader: user1.address, // trader
            broker: broker.address, // broker
            relayer: user0.address, // relayer
            // broker: user0.address,
            // relayer: user0.address,
            liquidityPool: liquidityPool.address, // liquidityPool
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

        expect(await broker.isOrderCanceled(order)).to.be.false;
        await broker.cancelOrder(order);
        expect(await broker.isOrderCanceled(order)).to.be.true;

        await broker.batchTrade([compressed], [toWei("-0.5")], [toWei("0")]);
        var { position } = await liquidityPool.getMarginAccount(0, user1.address);
        expect(position).to.equal(toWei("0"));
    })

    it('broker - fee', async () => {
        let now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("1000"), now);
        await oracle.setIndexPrice(toWei("1000"), now);

        await ctk.mint(user1.address, toWei("10000"))
        await ctk.mint(user2.address, toWei("10000"))
        await ctk.connect(user1).approve(liquidityPool.address, toWei("10000"))
        await ctk.connect(user2).approve(liquidityPool.address, toWei("10000"))
        await liquidityPool.connect(user1).deposit(0, user1.address, toWei("10000"));
        await liquidityPool.connect(user2).addLiquidity(toWei("10000"));

        const order = {
            trader: user1.address, // trader
            broker: broker.address, // broker
            relayer: user0.address, // relayer
            // broker: user0.address,
            // relayer: user0.address,
            liquidityPool: liquidityPool.address, // liquidityPool
            referrer: "0x0000000000000000000000000000000000000000", // referrer
            minTradeAmount: toWei("0.1"),
            amount: toWei("-0.5"),
            limitPrice: toWei("0"),
            triggerPrice: toWei("0"),
            chainID: 31337,
            expiredAt: now + 10000,
            perpetualIndex: 0,
            brokerFeeLimit: 20,  // 20 gwei 000000000
            flags: 0x00000000,
            salt: 123456,
        };
        var orderHash = await testOrder.orderHash(order);
        const sig = await user1.signMessage(ethers.utils.arrayify(orderHash));
        var { r, s, v } = ethers.utils.splitSignature(sig);
        var compressed = await testOrder.compress(order, r, s, v, 0);
        expect(await testOrder.getSigner(order, sig)).to.equal(user1.address);

        await broker.batchTrade([compressed], [toWei("-0.5")], ["20000000000"]);
        var { position } = await liquidityPool.getMarginAccount(0, user1.address);
        expect(position).to.equal(toWei("0"));

        expect(await broker.balanceOf(user1.address)).to.equal(0)
        await broker.connect(user1).deposit({ value: toWei("1") })
        expect(await broker.balanceOf(user1.address)).to.equal(toWei("1"))

        await broker.batchTrade([compressed], [toWei("-0.5")], ["21000000000"]);
        var { position } = await liquidityPool.getMarginAccount(0, user1.address);
        expect(position).to.equal(toWei("0"));

        await broker.batchTrade([compressed], [toWei("-0.5")], ["20000000000"]);
        var { position } = await liquidityPool.getMarginAccount(0, user1.address);
        expect(position).to.equal(toWei("-0.5"));
        expect(await broker.balanceOf(user1.address)).to.equal("999999980000000000")

        await broker.connect(user1).withdraw("999999980000000000");
        expect(await broker.balanceOf(user1.address)).to.equal("0")
    })


    it("relay call", async () => {
        // test user0 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266, pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        // test user1 0x70997970c51812dc3a010c7d01b50e0d17dc79c8, pk = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        let now = Math.floor(Date.now() / 1000);
        await oracle.setMarkPrice(toWei("1000"), now);
        await oracle.setIndexPrice(toWei("1000"), now);

        await ctk.mint(user1.address, toWei("10000"))
        await ctk.connect(user1).approve(liquidityPool.address, toWei("10000"))

        const method = "deposit(uint256,address,int256)"
        const callData = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "int256"], [0, user1.address, 1000])
        const from = user1.address;
        const to = liquidityPool.address;
        const nonce = 0
        const expiration = now + 86400
        const gasLimit = 0

        const typedData = {
            types: {
                EIP712Domain: [
                    { name: "name", type: "string" },
                    { name: "version", type: "string" }
                ],
                Call: [
                    { name: 'chainId', type: 'uint256' },
                    { name: 'method', type: 'string' },
                    { name: 'broker', type: 'address' },
                    { name: 'from', type: 'address' },
                    { name: 'to', type: 'address' },
                    { name: 'callData', type: 'bytes' },
                    { name: 'nonce', type: 'uint32' },
                    { name: 'expiration', type: 'uint32' },
                    { name: 'gasLimit', type: 'uint64' }
                ]
            },
            primaryType: 'Call' as const,
            domain: {
                name: 'Mai L2 Call',
                version: 'v3.0'
            },
            message: {
                'chainId': 31337,
                'method': method,
                'broker': broker.address,
                'from': from,
                'to': to,
                'callData': callData,
                'nonce': nonce,
                'expiration': expiration,
                'gasLimit': gasLimit,
            }
        }

        const digest = TypedDataUtils.encodeDigest(typedData)
        var sigRaw = ecsign(Buffer.from(ethers.utils.hexlify(digest).slice(2), 'hex'), Buffer.from("59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", 'hex'))
        var sig = ethers.utils.joinSignature({ r: "0x" + sigRaw.r.toString('hex'), s: "0x" + sigRaw.s.toString('hex'), v: sigRaw.v });

        const userData1 = ethers.utils.solidityPack(["address", "uint32", "uint32", "uint32"], [from, nonce, expiration, gasLimit])
        const userData2 = ethers.utils.solidityPack(["address", "uint32", "uint64"], [to, 0, 0])
        await broker.callFunction(
            userData1,
            userData2,
            method,
            callData,
            sig
        );

        var result = await liquidityPool.getMarginAccount(0, user1.address);
        console.log(result.cash.toString());
        expect(result.cash).to.equal(1000)
    })
})