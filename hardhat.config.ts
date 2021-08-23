import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "./misc/typechain-ethers-v5-mcdex"
import "hardhat-contract-sizer";
// import "hardhat-gas-reporter";
// import "hardhat-abi-exporter";
import "solidity-coverage"

// const pk = process.env["PK"]

task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task("encode", "Encode calldata")
    .addPositionalParam("sig", "Signature of contract to deploy")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split(',')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        console.log("encoded calldata", calldata)
    })


task("deploy", "Deploy a single contract")
    .addPositionalParam("name", "Name of contract to deploy")
    .addOptionalPositionalParam("args", "Args of contract constructor, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split('|')
        }
        const linkReferences = await retrieveLinkReferences('./artifacts/contracts')
        const links = {}
        const go = async (name) => {
            const innerLinks = {}
            for (let linkedContractName of linkReferences[name] || []) {
                if (linkedContractName in links) {
                    innerLinks[linkedContractName] = links[linkedContractName];
                } else {
                    const deployed = await go(linkedContractName);
                    innerLinks[linkedContractName] = deployed;
                    links[linkedContractName] = deployed;
                }
            }
            const factory = await hre.ethers.getContractFactory(name, { libraries: innerLinks });
            const deployed = await factory.deploy(...args.args);
            console.log(name, 'deployed at', deployed.address);
            return deployed.address;
        }
        await go(args.name);
    })

task("send", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split('|')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        // console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);

        const tx = await signer.sendTransaction({
            to: args.address,
            from: signer._address,
            data: calldata,
        });
        console.log(tx);
        console.log(await tx.wait());
    })

task("call", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split('|')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        //       console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);
        const result = await signer.call({
            to: args.address,
            data: calldata,
        })
        console.log("result", result);
    })

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        local: {
            url: "http://localhost:8545",
            allowUnlimitedContractSize: true
        },
        hardhat: {
            allowUnlimitedContractSize: true
        },
        kovan: {
            url: "https://kovan.infura.io/v3/",
            gasPrice: 1e9,
            // accounts: [pk],
            timeout: 300000,
            confirmations: 1,
        },
        bscTestnet: {
            url: "https://data-seed-prebsc-2-s1.binance.org:8545/",
            gasPrice: 20e9,
            // accounts: [""],
            timeout: 300000,
            confirmations: 1,
        },
<<<<<<< HEAD
        arb: {
            url: "https://kovan5.arbitrum.io/rpc",
            gasPrice: 3e8,
            // accounts: [pk],
=======
        arbrinkeby: {
            url: "https://rinkeby.arbitrum.io/rpc",
            gasPrice: 1e9,
            accounts: [pk],
>>>>>>> 597be68078824d6e1df725dd5b876ae6f4508571
            timeout: 300000,
            confirmations: 1,
        },
    },
    solidity: {
        version: "0.7.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000
            }
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: false,
        disambiguatePaths: false,
    },
    abiExporter: {
        path: './abi',
        clear: false,
        flat: true,
        only: ['PoolCreator', 'LiquidityPool'],
    },
    mocha: {
        timeout: 60000
    }
};
