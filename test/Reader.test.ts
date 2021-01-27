const { ethers } = require("hardhat");
const { expect } = require("chai");
import "./helper";
import {
    toWei,
    fromWei,
    createFactory,
    createContract,
    createLiquidityPoolFactory
} from "../scripts/utils";

import { CustomErc20Factory } from "../typechain/CustomErc20Factory"
import { LiquidityPoolFactory } from "../typechain/LiquidityPoolFactory"

describe("Reader", () => {
    var accounts;
    var user0;
    var user1;
    var user2;
    var user3;
    var vault;
    var none;

    var weth;
    var symbol;
    var ctk;
    var lpTokenTemplate;
    var govTemplate;
    var maker;
    var perp;
    var oracle1;
    var oracle2;
    var reader;
    const vaultFeeRate = toWei("0.001");

    let updatePrice = async (price1, price2) => {
        let now = Math.floor(Date.now() / 1000);
        await oracle1.setMarkPrice(price1, now);
        await oracle1.setIndexPrice(price1, now);
        await oracle2.setMarkPrice(price2, now);
        await oracle2.setIndexPrice(price2, now);
    }

    beforeEach("main - 6 decimals", async () => {
        // users
        accounts = await ethers.getSigners();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        vault = accounts[9];
        none = "0x0000000000000000000000000000000000000000";

        // create components
        weth = await createContract("WETH9");
        symbol = await createContract("SymbolService", [10000]);
        ctk = await createContract("CustomERC20", ["collateral", "CTK", 6]);
        lpTokenTemplate = await createContract("ShareToken");
        govTemplate = await createContract("TestGovernor");
        maker = await createContract(
            "PoolCreator",
            [
                govTemplate.address,
                lpTokenTemplate.address,
                weth.address,
                symbol.address,
                vault.address,
                vaultFeeRate,
            ]
        );
        await symbol.addWhitelistedFactory(maker.address);
        var perpTemplate = await (await createLiquidityPoolFactory()).deploy();
        await maker.addVersion(perpTemplate.address, 0, "initial version");

        const perpAddr = await maker.callStatic.createLiquidityPool(ctk.address, 6, false, 998);
        await maker.createLiquidityPool(ctk.address, 6, false, 998);

        perp = await LiquidityPoolFactory.connect(perpAddr, user0);
        reader = await createContract("Reader");

        // oracle
        oracle1 = await createContract("OracleWrapper", ["USD", "BTC"]);
        oracle2 = await createContract("OracleWrapper", ["USD", "ETH"]);
        await updatePrice(toWei("500"), toWei("500"))

        await perp.createPerpetual(oracle1.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.createPerpetual(oracle2.address,
            [toWei("0.1"), toWei("0.05"), toWei("0.001"), toWei("0.001"), toWei("0.2"), toWei("0.02"), toWei("0.00000002"), toWei("0.5"), toWei("1000")],
            [toWei("0.01"), toWei("0.1"), toWei("0.06"), toWei("0.1"), toWei("5"), toWei("0.05")],
            [toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0"), toWei("0")],
            [toWei("0.1"), toWei("0.2"), toWei("0.2"), toWei("0.5"), toWei("10"), toWei("0.99")],
        )

        await perp.runLiquidityPool();

        // get initial coins
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));
        const ctkUser1 = await CustomErc20Factory.connect(ctk.address, user1);
        await ctkUser1.approve(perp.address, toWei("100000"));
        const ctkUser2 = await CustomErc20Factory.connect(ctk.address, user2);
        await ctkUser2.approve(perp.address, toWei("100000"));

        // deposit
        const perpUser1 = await LiquidityPoolFactory.connect(perp.address, user1);
        await perpUser1.deposit(0, user1.address, toWei("100"));

        // lp
        await updatePrice(toWei("501"), toWei("601"));
        const perpUser2 = await LiquidityPoolFactory.connect(perp.address, user2);
        await perpUser2.addLiquidity(toWei("1000"));

        // trade 1
        await updatePrice(toWei("502"), toWei("603"));
        let now = Math.floor(Date.now() / 1000);
        await perpUser1.trade(0, user1.address, toWei("0.1"), toWei("1000"), now + 999999, none, 0);
    });

    it('getAccountStorage', async () => {
        const account = await reader.callStatic.getAccountStorage(
            perp.address, 0, perp.address
        );
        expect(account.isSynced).to.be.true;
        expect(account.marginAccount.position).approximateBigNumber(toWei("-0.1"));
        expect(account.marginAccount.cash.gt('0')).to.be.true;
    });

    it('getLiquidityPoolStorage', async () => {
        const pool = await reader.callStatic.getLiquidityPoolStorage(perp.address);
        expect(pool.isSynced).to.be.true;
        expect(pool.pool.isRunning).to.be.true;

        expect(pool.pool.isFastCreationEnabled).to.be.false;
        expect(pool.pool.addresses[0]).to.equal(maker.address) // creator
        expect(pool.pool.addresses[1]).to.equal(user0.address) // operator
        expect(pool.pool.addresses[2]).to.equal(none) // transferringOperator
        // expect(pool.pool.addresses[3]).to.equal(gov.address) // governor is a template
        // expect(pool.pool.addresses[4]).to.equal(lpToken.address) // shareToken is a template
        expect(pool.pool.addresses[5]).to.equal(ctk.address) // collateralToken
        expect(pool.pool.addresses[6]).to.equal(vault.address) // vault
        expect(pool.pool.vaultFeeRate).approximateBigNumber(vaultFeeRate);
        expect(pool.pool.poolCash).approximateBigNumber(toWei("1000"));
        expect(pool.pool.collateralDecimals).to.equal(6);
        expect(pool.pool.perpetuals.length).to.equal(2);
        expect(pool.pool.fundingTime).not.to.equal(0);
        expect(pool.pool.perpetuals[0].state).to.equal(2);
        expect(pool.pool.perpetuals[0].oracle).to.equal(oracle1.address);
        expect(pool.pool.perpetuals[0].nums[0].gt('0')).to.be.true; // totalCollateral
        expect(pool.pool.perpetuals[0].nums[1]).approximateBigNumber(toWei("502")); // markPrice
        expect(pool.pool.perpetuals[0].nums[2]).approximateBigNumber(toWei("502")); // indexPrice
        expect(pool.pool.perpetuals[0].symbol).to.equal(10000);
        expect(pool.pool.perpetuals[0].underlyingAsset).to.equal('BTC');
        expect(pool.pool.perpetuals[0].isMarketClosed).to.be.false;
        expect(pool.pool.perpetuals[0].ammCashBalance.gt(0)).to.be.true;;
        expect(pool.pool.perpetuals[0].ammPositionAmount).approximateBigNumber(toWei("-0.1"));
        expect(pool.pool.perpetuals[1].state).to.equal(2);
        expect(pool.pool.perpetuals[1].oracle).to.equal(oracle2.address);
        expect(pool.pool.perpetuals[1].nums[0]).approximateBigNumber(toWei("0")); // totalCollateral
        expect(pool.pool.perpetuals[1].nums[1]).approximateBigNumber(toWei("603")); // markPrice
        expect(pool.pool.perpetuals[1].nums[2]).approximateBigNumber(toWei("603")); // indexPrice
        expect(pool.pool.perpetuals[1].symbol).to.equal(10001);
        expect(pool.pool.perpetuals[1].underlyingAsset).to.equal('ETH');
        expect(pool.pool.perpetuals[1].isMarketClosed).to.be.false;
        expect(pool.pool.perpetuals[1].ammCashBalance).approximateBigNumber(toWei("0"));
        expect(pool.pool.perpetuals[1].ammPositionAmount).approximateBigNumber(toWei("0"));
    });

    it('zero price', async () => {
        await updatePrice(toWei("501"), toWei("0"));
        const pool = await reader.callStatic.getLiquidityPoolStorage(perp.address);
        expect(pool.isSynced).to.be.false;

        expect(pool.pool.isFastCreationEnabled).to.be.false;
        expect(pool.pool.addresses[0]).to.equal(maker.address) // creator
        expect(pool.pool.addresses[1]).to.equal(user0.address) // operator
        expect(pool.pool.addresses[2]).to.equal(none) // transferringOperator
        // expect(pool.pool.addresses[3]).to.equal(gov.address) // governor is a template
        // expect(pool.pool.addresses[4]).to.equal(lpToken.address) // shareToken is a template
        expect(pool.pool.addresses[5]).to.equal(ctk.address) // collateralToken
        expect(pool.pool.addresses[6]).to.equal(vault.address) // vault
        expect(pool.pool.vaultFeeRate).approximateBigNumber(vaultFeeRate);
        expect(pool.pool.poolCash).approximateBigNumber(toWei("1000"));
        expect(pool.pool.collateralDecimals).to.equal(6);
        expect(pool.pool.perpetuals.length).to.equal(2);
        expect(pool.pool.fundingTime).not.to.equal(0);
        expect(pool.pool.perpetuals[0].state).to.equal(2);
        expect(pool.pool.perpetuals[0].oracle).to.equal(oracle1.address);
        expect(pool.pool.perpetuals[0].nums[0].gt('0')).to.be.true; // totalCollateral
        expect(pool.pool.perpetuals[0].nums[1]).approximateBigNumber(toWei("502")); // markPrice
        expect(pool.pool.perpetuals[0].nums[2]).approximateBigNumber(toWei("502")); // indexPrice
        expect(pool.pool.perpetuals[0].symbol).to.equal(10000);
        expect(pool.pool.perpetuals[0].underlyingAsset).to.equal('BTC');
        expect(pool.pool.perpetuals[0].isMarketClosed).to.be.false;
        expect(pool.pool.perpetuals[0].ammCashBalance.gt(0)).to.be.true;;
        expect(pool.pool.perpetuals[0].ammPositionAmount).approximateBigNumber(toWei("-0.1"));
        expect(pool.pool.perpetuals[1].state).to.equal(2);
        expect(pool.pool.perpetuals[1].oracle).to.equal(oracle2.address);
        expect(pool.pool.perpetuals[1].nums[0]).approximateBigNumber(toWei("0")); // totalCollateral
        expect(pool.pool.perpetuals[1].nums[1]).approximateBigNumber(toWei("603")); // markPrice
        expect(pool.pool.perpetuals[1].nums[2]).approximateBigNumber(toWei("603")); // indexPrice
        expect(pool.pool.perpetuals[1].symbol).to.equal(10001);
        expect(pool.pool.perpetuals[1].underlyingAsset).to.equal('ETH');
        expect(pool.pool.perpetuals[1].isMarketClosed).to.be.false;
        expect(pool.pool.perpetuals[1].ammCashBalance).approximateBigNumber(toWei("0"));
        expect(pool.pool.perpetuals[1].ammPositionAmount).approximateBigNumber(toWei("0"));
    });
})
