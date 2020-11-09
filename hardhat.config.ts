import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "hardhat-typechain";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "hardhat-abi-exporter";

task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
      hardhat: {
      },
    },
    solidity: {
      version: "0.7.4",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
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
      only: ['PereptualMaker', 'Perpetual'],
    }
};