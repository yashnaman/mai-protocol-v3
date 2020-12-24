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

    it("signature1", async () => {
        const hash1 = await signature.hashMessage("0x3940be676247c41da1ff1cd811b9bd6c463a0ab6935f3c25293c1ef1404787ea");
        const addr = await signature.recoverMessage(hash1, "0x624349e9a99774a838ebf82336dd3a2b889f930512957218071033067aa515c104aa51d9906407293f6f4b014f9fc998ec28fd7d05088a8e4254c08628ab8c8d1b");
        const addr2 = await signature.recoverMessage2(hash1, "0x624349e9a99774a838ebf82336dd3a2b889f930512957218071033067aa515c104aa51d9906407293f6f4b014f9fc998ec28fd7d05088a8e4254c08628ab8c8d1b");
        console.log(addr, addr2)
    })



});