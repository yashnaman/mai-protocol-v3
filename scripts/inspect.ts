const hre = require("hardhat");
const chalk = require("chalk");
const ethers = hre.ethers;

import { DeploymentOptions } from "./deployer/deployer";
import { readOnlyEnviron } from "./deployer/environ";
import { printError } from "./deployer/utils";

function passOrWarn(title, cond) {
  return cond ? chalk.greenBright(title) : chalk.red(title);
}

const ENV: DeploymentOptions = {
  network: hre.network.name,
  artifactDirectory: "./artifacts/contracts",
  addressOverride: {},
};

async function inspectPoolCreator(deployer) {
  console.log("====PoolCreator====");
  const address = await deployer.addressOf("PoolCreator");
  console.log("address:", address);
  const poolCreator = await deployer.getDeployedContract("PoolCreator");
  const poolUpgradeAdmin = await poolCreator.upgradeAdmin();
  console.log("poolUpgradeAdmin:", poolUpgradeAdmin);
  var owner = await poolCreator.owner();
  console.log("owner:", owner);
  var implementation = await deployer.getImplementation(await deployer.addressOf("PoolCreator"));
  console.log("implementation:", implementation);
  var upgradeAdmin = await deployer.getAdminOfUpgradableContract(await deployer.addressOf("PoolCreator"));
  console.log("upgradeAdmin:", upgradeAdmin);
  const keepers = await poolCreator.listKeepers(0, 100);
  console.log("whitelist keepers:", keepers);
  console.log("guardian:");
  var filter = poolCreator.filters.AddGuardian();
  var logs = await poolCreator.queryFilter(filter);
  for (const log of logs) {
    console.log("    add ", log.args[0]);
  }
  filter = poolCreator.filters.TransferGuardian();
  logs = await poolCreator.queryFilter(filter);
  for (const log of logs) {
    console.log("    transfer from ", log.args[0], " to ", log.args[0]);
  }
  filter = poolCreator.filters.RenounceGuardian();
  logs = await poolCreator.queryFilter(filter);
  for (const log of logs) {
    console.log("    renounce ", log.args[0]);
  }
  const vault = await poolCreator.getVault();
  const vaultFeeRate = await poolCreator.getVaultFeeRate();
  console.log("vault:", vault, "vault fee rate:", Number(vaultFeeRate.toString()) / 10 ** 18);

  console.log("\n====SymbolService====");
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(await deployer.addressOf("SymbolService"));
  console.log("upgradeAdmin:", upgradeAdmin);
  const symbolService = await deployer.getDeployedContract("SymbolService");
  owner = await symbolService.owner();
  console.log("owner:", owner);
  console.log("whitelist factory:");
  filter = symbolService.filters.AddWhitelistedFactory();
  logs = await symbolService.queryFilter(filter);
  for (const log of logs) {
    console.log("    add ", log.args[0]);
  }
  filter = symbolService.filters.RemoveWhitelistedFactory();
  logs = await symbolService.queryFilter(filter);
  for (const log of logs) {
    console.log("    remove ", log.args[0]);
  }

  console.log("\n====MCDEX pool====");
  const poolAddress = "0xaB324146C49B23658E5b3930E641BDBDf089CbAc";
  const pool = await deployer.getContractAt("Getter", poolAddress);
  const data = await pool.getLiquidityPoolInfo();
  console.log("operator:", data.addresses[1]);
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(poolAddress);
  console.log("upgradeAdmin:", upgradeAdmin);

  console.log("\n====MultiOracle====");
  const MCDEXMultiOracleAddress = "0x57469550b9A42d2fd964E67A9DD1DE3d9169b291";
  const MCDEXMultiOracle = await deployer.getContractAt("MCDEXMultiOracle", MCDEXMultiOracleAddress);
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(MCDEXMultiOracleAddress);
  console.log("upgradeAdmin:", upgradeAdmin);
  implementation = await deployer.getImplementation(MCDEXMultiOracleAddress);
  console.log("implementation:", implementation);
  console.log("default admin role:");
  var role = ethers.constants.HashZero;
  var roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  console.log("price setter role:");
  role = ethers.utils.solidityKeccak256(["string"], ["PRICE_SETTER_ROLE"]);
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  console.log("market closer role:");
  role = ethers.utils.solidityKeccak256(["string"], ["MARKET_CLOSER_ROLE"]);
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  console.log("terminater role:");
  role = ethers.utils.solidityKeccak256(["string"], ["TERMINATER_ROLE"]);
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }

  console.log("\n====SingleOracle====");
  const UpgradeableBeaconAddress = "0x1021b725C8C10DC6240c9f1F151095d798906D3c";
  const UpgradeableBeacon = await deployer.getContractAt("UpgradeableBeacon", UpgradeableBeaconAddress);
  implementation = await UpgradeableBeacon.implementation();
  console.log("UpgradeableBeacon:");
  console.log("    implementation:", implementation);
  var owner = await UpgradeableBeacon.owner();
  console.log("    owner:", owner);
  const ETHOracleAddress = "0x1Cf22B7f84F86c36Cb191BB24993EdA2b191399E";
  console.log("MCDEXSingleOracle:");
  var beacon = await deployer.getBeacon(ETHOracleAddress);
  console.log("    ETH beacon:", beacon);
  const BTCOracleAddress = "0x1Cf22B7f84F86c36Cb191BB24993EdA2b191399E";
  beacon = await deployer.getBeacon(BTCOracleAddress);
  console.log("    BTC beacon:", beacon);
}

async function main(_, deployer, accounts) {
  await inspectPoolCreator(deployer);
}

ethers
  .getSigners()
  .then((accounts) => readOnlyEnviron(ethers, ENV, main, accounts))
  .then(() => process.exit(0))
  .catch((error) => {
    printError(error);
    process.exit(1);
  });
