import { expect } from "chai";
const { ethers } = require("hardhat");
import { TypedDataUtils } from 'ethers-eip712'
import {
    toWei,
    fromWei,
    fromBytes32,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

import "./helper";

describe('Broker', () => {
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

        let relay;
        let ctk;
        let oracle;

        beforeEach(async () => {
            user0 = accounts[0];
            user1 = accounts[1];
            user2 = accounts[2];
            user3 = accounts[3];
            user4 = accounts[4];
            user5 = accounts[5];


            relay = await createContract("Broker");
        })


        // it('relay', async () => {
        //     const calc = await createContract("TestCalc");
        //     const typedData = {
        //         types: {
        //             EIP712Domain: [
        //                 { name: "name", type: "string" },
        //                 { name: "version", type: "string" },
        //                 { name: "chainID", type: "uint256" }
        //             ],
        //             Call: [
        //                 { name: 'method', type: 'string' },
        //                 { name: 'broker', type: 'address' },
        //                 { name: 'from', type: 'address' },
        //                 { name: 'to', type: 'address' },
        //                 { name: 'callData', type: 'bytes' },
        //                 { name: 'nonce', type: 'uint32' },
        //                 { name: 'expiration', type: 'uint32' },
        //                 { name: 'gasLimit', type: 'uint64' }
        //             ]
        //         },
        //         primaryType: 'Call' as const,
        //         domain: {
        //             name: 'Mai L2 Call',
        //             version: 'v3.0',
        //             chainID: 31337
        //         },
        //         message: {
        //             'method': "deposit(uint256,address,int256)",
        //             'broker': relay.address,
        //             'from': user0.address,
        //             'to': calc.address,
        //             'callData': "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e8735cd053fc738170011f7ebc4117f285fe9d0000000000000000000000000000000000000000000000000000000000002710",
        //             'nonce': 0,
        //             'expiration': 1711564491,
        //             'gasLimit': "1000000000000000000",
        //         }
        //     }

        //     // console.log("[SO] messageData =>", await calc.messageData(
        //     //     user0.address,
        //     //     "add(uint256)",
        //     //     "0x0000000000000000000000000000000000000000000000000000000000000064",
        //     //     0,
        //     //     1711564491,
        //     //     10000000
        //     // ));
        //     // console.log("[SO] domainHash  =>", await calc.domainHash());

        //     // console.log("[SO] messageHash =>", await calc.messageHash(
        //     //     user0.address,
        //     //     "add(uint256)",
        //     //     "0x0000000000000000000000000000000000000000000000000000000000000064",
        //     //     0,
        //     //     1711564491,
        //     //     10000000
        //     // ));

        //     // console.log("[SO] signedHash  =>", await calc.signedHash(
        //     //     user0.address,
        //     //     "add(uint256)",
        //     //     "0x0000000000000000000000000000000000000000000000000000000000000064",
        //     //     0,
        //     //     1711564491,
        //     //     10000000
        //     // ));

        //     const digest = TypedDataUtils.encodeDigest(typedData)
        //     const signature = await user0.signMessage(digest)

        //     // console.log(ethers.utils.hexlify(signature));

        //     let sig = ethers.utils.splitSignature(signature);
        //     // console.log(sig);

        //     const userData1 = user0.address + "00000000660466cb00989680" // 0, 1711564491, 10000000
        //     const userData2 = calc.address + "000000000000000000000000" // calc.address, 0
        //     await relay.callFunction(
        //         userData1,
        //         userData2,
        //         "deposit(uint256,address,int256)",
        //         "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e8735cd053fc738170011f7ebc4117f285fe9d0000000000000000000000000000000000000000000000000000000000002710",
        //         signature
        //     );
        //     expect(await calc.balanceOf(0, "0x02e8735cd053fc738170011F7eBc4117f285fE9D")).to.equal(10000);
        // })


        it('relay2', async () => {
            const calc = await createContract("TestCalc");
            const typedData = {
                types: {
                    EIP712Domain: [
                        { name: "name", type: "string" },
                        { name: "version", type: "string" },
                        { name: "chainID", type: "uint256" }
                    ],
                    Call: [
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
                    version: 'v3.0',
                    chainID: 1337
                },
                message: {
                    'method': "deposit(uint256,address,int256)",
                    'broker': "0xf57e9028ABCB70C7bA63782485eC1bDEF94F6975",
                    'from': "0x9e7b8106c0a31ddf9fcb9c60af4c1163bba9526d",
                    'to': "0x86B34D166cb093bF65f9af94A1551279cd4777A6",
                    'callData': "0x0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000913906f5751c5ef6dff11c21280f3cb4f78fc0c4000000000000000000000000000000000000000000000000000000000000007b",
                    'nonce': 0,
                    'expiration': 1611656229,
                    'gasLimit': 0,
                }
            }

            const provider = new ethers.providers.JsonRpcProvider("http://server10.jy.mcarlo.com:8747");
            const signer = new ethers.Wallet("0x099bb08436e5f87d0a248179b654f46f0f89e814f1d0a46bc3ecce7611743d29", provider)

            const digest = TypedDataUtils.encodeDigest(typedData)
            const signature = await signer.signMessage(digest)


            console.log(await provider.send("eth_sign", ["0x6766F3CFD606E1E428747D3364baE65B6f914D56", ethers.utils.hexlify(digest)]));


            // let sig = ethers.utils.splitSignature(signature);
            // // console.log(sig);

            // const userData1 = user0.address + "00000000660466cb00989680" // 0, 1711564491, 10000000
            // const userData2 = calc.address + "000000000000000000000000" // calc.address, 0
            // await relay.callFunction(
            //     userData1,
            //     userData2,
            //     "deposit(uint256,address,int256)",
            //     "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e8735cd053fc738170011f7ebc4117f285fe9d0000000000000000000000000000000000000000000000000000000000002710",
            //     signature
            // );
            // expect(await calc.balanceOf(0, "0x02e8735cd053fc738170011F7eBc4117f285fE9D")).to.equal(10000);
        })

    })
})