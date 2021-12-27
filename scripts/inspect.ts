const hre = require("hardhat");
const chalk = require("chalk");
const ethers = hre.ethers;
const BigNumber = require("bignumber.js");

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
  console.log("address(proxy):", await deployer.addressOf("PoolCreator"));
  const poolCreator = await deployer.getDeployedContract("PoolCreator");
  const poolUpgradeAdmin = await poolCreator.upgradeAdmin();
  console.log("poolUpgradeAdmin (nobody can transfer the owner):", poolUpgradeAdmin);
  var owner = await poolCreator.owner();
  console.log("owner:", owner);
  var implementation = await deployer.getImplementation(await deployer.addressOf("PoolCreator"));
  console.log("implementation:", implementation);
  var upgradeAdmin = await deployer.getAdminOfUpgradableContract(await deployer.addressOf("PoolCreator"));
  console.log("upgradeAdmin:", upgradeAdmin);
  const keepers = await poolCreator.listKeepers(0, 100);
  console.log("whitelist keepers:", keepers);
  /* block too much
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
  */
  const vault = await poolCreator.getVault();
  const vaultFeeRate = await poolCreator.getVaultFeeRate();
  console.log("vault:", vault, "vault fee rate:", new BigNumber(vaultFeeRate.toString()).shiftedBy(-18).toFixed());

  console.log("\n====SymbolService====");
  console.log("address(proxy):", await deployer.addressOf("SymbolService"));
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(await deployer.addressOf("SymbolService"));
  console.log("upgradeAdmin:", upgradeAdmin);
  const symbolService = await deployer.getDeployedContract("SymbolService");
  owner = await symbolService.owner();
  console.log("owner:", owner);
  /* block too much
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
  */

  console.log("\n====MCDEXFoundation pool====");
  const poolAddress = "0xaB324146C49B23658E5b3930E641BDBDf089CbAc";
  console.log("address:", poolAddress);
  const pool = await deployer.getContractAt("Getter", poolAddress);
  const data = await pool.getLiquidityPoolInfo();
  console.log("operator:", data.addresses[1]);
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(poolAddress);
  console.log("upgradeAdmin:", upgradeAdmin);

  console.log("\n====MCDEXMultiOracle====");
  const MCDEXMultiOracleAddress = "0x57469550b9A42d2fd964E67A9DD1DE3d9169b291";
  console.log("address:", MCDEXMultiOracleAddress);
  const MCDEXMultiOracle = await deployer.getContractAt("MCDEXMultiOracle", MCDEXMultiOracleAddress);
  upgradeAdmin = await deployer.getAdminOfUpgradableContract(MCDEXMultiOracleAddress);
  console.log("upgradeAdmin:", upgradeAdmin);
  implementation = await deployer.getImplementation(MCDEXMultiOracleAddress);
  console.log("implementation:", implementation);
  var role = ethers.constants.HashZero;
  console.log("default admin role (", role, "):");
  var roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  role = ethers.utils.solidityKeccak256(["string"], ["PRICE_SETTER_ROLE"]);
  console.log("price setter role (", role, "):");
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  role = ethers.utils.solidityKeccak256(["string"], ["MARKET_CLOSER_ROLE"]);
  console.log("market closer role (", role, "):");
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }
  role = ethers.utils.solidityKeccak256(["string"], ["TERMINATER_ROLE"]);
  console.log("terminater role (", role, "):");
  roleMemberCount = await MCDEXMultiOracle.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await MCDEXMultiOracle.getRoleMember(role, i));
  }

  console.log("\n====MCDEXSingleOracle====");
  const UpgradeableBeaconAddress = "0x1021b725C8C10DC6240c9f1F151095d798906D3c";
  const UpgradeableBeacon = await deployer.getContractAt("UpgradeableBeacon", UpgradeableBeaconAddress);
  implementation = await UpgradeableBeacon.implementation();
  console.log("UpgradeableBeacon:");
  console.log("    address:", UpgradeableBeaconAddress);
  console.log("    implementation:", implementation);
  var owner = await UpgradeableBeacon.owner();
  console.log("    owner:", owner);
  const ETHOracleAddress = "0x1Cf22B7f84F86c36Cb191BB24993EdA2b191399E";
  console.log("MCDEXSingleOracle:");
  var beacon = await deployer.getBeacon(ETHOracleAddress);
  console.log("    ETH");
  console.log("      address:", ETHOracleAddress);
  console.log("      beacon:", beacon);
  const BTCOracleAddress = "0x6ee936BdBD329063E8CE1d13F42eFEf912E85221";
  beacon = await deployer.getBeacon(BTCOracleAddress);
  console.log("    BTC");
  console.log("      address:", BTCOracleAddress);
  console.log("      beacon:", beacon);

  console.log("\n====TunableOracleRegister====");
  const TunableOracleRegisterAddress = "0x43800D850C87d5D585D8DDF3DFB23152A826cDeB";
  console.log("address:", TunableOracleRegisterAddress);
  const TunableOracleRegister = await deployer.getContractAt("TunableOracleRegister", TunableOracleRegisterAddress);
  console.log("upgradeAdmin:", await deployer.getAdminOfUpgradableContract(TunableOracleRegister.address));
  console.log("implementation:", await deployer.getImplementation(TunableOracleRegister.address));
  console.log("beacon implementation(for TunableOracle):", await TunableOracleRegister.implementation());
  var role = ethers.constants.HashZero;
  console.log("default admin role (", role, "):");
  var roleMemberCount = await TunableOracleRegister.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await TunableOracleRegister.getRoleMember(role, i));
  }
  role = ethers.utils.solidityKeccak256(["string"], ["TERMINATER_ROLE"]);
  console.log("terminater role (", role, "):");
  roleMemberCount = await TunableOracleRegister.getRoleMemberCount(role);
  for (let i = 0; i < Number(roleMemberCount); i++) {
    console.log("    ", await TunableOracleRegister.getRoleMember(role, i));
  }

  for (let tunableOracleAddress of ["0x9F64F38F18530d70B0caD57d6B929Fa8f371d6c6", "0x78c9014568f8677df0beee444b224e09df519d9e"]) {
    console.log("\n====TunableOracle====", tunableOracleAddress);
    const TunableOracle = await deployer.getContractAt("TunableOracle", tunableOracleAddress);
    console.log("externalOracle:", await TunableOracle.externalOracle());
    console.log("fineTuner:", await TunableOracle.fineTuner());
  }

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
