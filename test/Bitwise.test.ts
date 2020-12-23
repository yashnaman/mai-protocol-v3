import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    toWei,
    createContract,
    getAccounts,
} from "../scripts/utils";

getDescription("Order", () => {
    var testBitwise;
    let accounts;

    before(async () => {
        accounts = await getAccounts();
        testBitwise = await createContract("TestBitwise");
    })

    it("normal", async () => {
        expect(await testBitwise.test(0x7, 0x1)).to.be.true;
        expect(await testBitwise.test(0x7, 0x3)).to.be.true;
        expect(await testBitwise.test(0x1, 0x2)).to.be.false;

        expect(await testBitwise.set(0x1, 0x2)).to.equal(0x3);
        expect(await testBitwise.set(0x1, 0x4)).to.equal(0x5);
        expect(await testBitwise.set(0x1, 0x1)).to.equal(0x1);

        expect(await testBitwise.clean(0x7, 0x1)).to.equal(0x6);
        expect(await testBitwise.clean(0x7, 0x2)).to.equal(0x5);
        expect(await testBitwise.clean(0x7, 0x4)).to.equal(0x3);
        expect(await testBitwise.clean(0x1, 0x2)).to.equal(0x1);
    })
});