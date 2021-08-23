const ethers = require("ethers")
function toWei(n) { return ethers.utils.parseEther(n) }

function printNumberArray(arr) {
  console.log('[' + arr.map(x => `"${x.toString()}"`).join(',') + ']')
}

const OperatorProxy = new ethers.utils.Interface([
  'function updatePerpetualRiskParameter(address liquidityPool, uint256 perpetualIndex, int256[8] calldata riskParams)',
  'function propose(address liquidityPool, string[] calldata signatures, bytes[] calldata calldatas, string calldata description) external returns (uint256)',
  'function proposeToUpgradeAndCall(address liquidityPool, bytes32 targetVersionKey, bytes calldata dataForLiquidityPool, bytes calldata dataForGovernor, string calldata description) external returns (uint256)',
  'function createPerpetual(address liquidityPool, address oracle, int256[9] calldata baseParams, int256[8] calldata riskParams, int256[8] calldata minRiskParamValues, int256[8] calldata maxRiskParamValues)',
])
const LiquidityPool = new ethers.utils.Interface([
  'function createPerpetual(address oracle, int256[9] calldata baseParams, int256[8] calldata riskParams, int256[8] calldata minRiskParamValues, int256[8] calldata maxRiskParamValues)',
  'function propose(string[] calldata signatures, bytes[] calldata calldatas, string calldata description)',
])

// ===============================================================================================
//                                    updatePerpetualRiskParameter
// ===============================================================================================
// alpha           beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
// mainnet!
// const risk = [toWei("0.001"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10")]
// mainnet test
// const risk = [toWei("0.01"), toWei("0.495"),      toWei("0.3"),     toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10")]
// printNumberArray(risk)
// console.log(
//   OperatorProxy.encodeFunctionData("updatePerpetualRiskParameter", [
//     '0xab324146c49b23658e5b3930e641bdbdf089cbac', // MAIN USDC POOL!
//     0,
//     risk
//   ])
// )
// ===============================================================================================
//                                    vote - createPerpetual
// ===============================================================================================
// console.log(
//   OperatorProxy.encodeFunctionData("propose", [
//     '0xe44287a9ee676e92e7687c28bb30ac6b5cb80bb2', // just test pool
//     [
//       // signatures
//       "createPerpetual(address,int256[9],int256[8],int256[8],int256[8])",
//     ],
//     // calldatas
//     [
//       '0x' + LiquidityPool.encodeFunctionData("createPerpetual", [
//         '0x6ee936BdBD329063E8CE1d13F42eFEf912E85221', // BTC oracle
//         // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
//         [toWei("0.04"), toWei("0.03"), toWei("0.00010"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
//         // alpha           beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
//         [toWei("0.00075"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10")],
//         [toWei("0"),       toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
//         [toWei("0.1"),     toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]    
//       ]).slice(2 + 8), // skip the function signature. important!
//     ],
//     JSON.stringify({
//       underlyingSymbol: "BTC",
//       collateralSymbol: "USDC",
//     }),
//   ])
// )
// ===============================================================================================
//                                     vote - upgrade
// ===============================================================================================
// console.log(
//   OperatorProxy.encodeFunctionData("proposeToUpgradeAndCall", [
//     '0x80918a9bb46bc1c2a03d3a9e09432ef4ee0bb048', // just test pool
//     '0xbf94422ecf1c5403b9b1da147df555694905675a0123d464f20b9858d5f3c083', // versionKey
//     '0x', // dataForLiquidityPool
//     '0x', // dataForGovernor
//     JSON.stringify({}), // description
//   ])
// )
// ===============================================================================================
//                     createPerpetual(only useful when isFastCreationEnabled)
// ===============================================================================================
// console.log(
//   OperatorProxy.encodeFunctionData("createPerpetual", [
//     '0xe44287a9ee676e92e7687c28bb30ac6b5cb80bb2', // just test pool
//     '0x6ee936BdBD329063E8CE1d13F42eFEf912E85221', // BTC oracle
//     // imr          mmr            operatorfr        lpfr              rebate        penalty        keeper       insur         oi
//     [toWei("0.04"), toWei("0.03"), toWei("0.00010"), toWei("0.00055"), toWei("0.2"), toWei("0.01"), toWei("10"), toWei("0.5"), toWei("3")],
//     // alpha           beta1            beta2             frLimit        lev         maxClose       frFactor        defaultLev
//     [toWei("0.00075"), toWei("0.0075"), toWei("0.00525"), toWei("0.01"), toWei("1"), toWei("0.05"), toWei("0.005"), toWei("10")],
//     [toWei("0"),       toWei("0"),      toWei("0"),       toWei("0"),    toWei("0"), toWei("0"),    toWei("0"),     toWei("0")],
//     [toWei("0.1"),     toWei("0.5"),    toWei("0.5"),     toWei("0.1"),  toWei("5"), toWei("1"),    toWei("0.1"),   toWei("10000000")]
//   ])
// )
// ===============================================================================================
// gnosis
// function submitTransaction(address destination, uint value, bytes memory data)
  
// 
