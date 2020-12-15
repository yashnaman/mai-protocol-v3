import { expect, use, util } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";
import { ethers, Signer, utils } from "ethers";
import {
    toWei,
    createContract,
    getAccounts,
} from "../scripts/utils";

describe("Order", () => {
    let accounts;
    var signature;

    before(async () => {
        accounts = await getAccounts();
        signature = await createContract("TestSignature");
    })

    it("signature", async () => {
        const hash1 = await signature.hashMessage("0x0000000000000000000000000000000000000000000000000000000000000000");
        const user1 = accounts[0];
        const sig = await user1.signMessage(ethers.utils.arrayify(hash1));
        const addr = await signature.recoverMessage(hash1, sig);
        console.log(user1.address, addr)
    })
});