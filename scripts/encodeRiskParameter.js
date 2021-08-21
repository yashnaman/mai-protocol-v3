const ethers = require("ethers")
function toWei(n) { return ethers.utils.parseEther(n) }

function printNumberArray(arr) {
  console.log('[' + arr.map(x => `"${x.toString()}"`).join(',') + ']')
}

const OperatorProxy = new ethers.utils.Interface([
  'function updatePerpetualRiskParameter(address liquidityPool, uint256 perpetualIndex, int256[8] calldata riskParams)',
  'function createPerpetual(address liquidityPool, address oracle, int256[9] calldata baseParams, int256[8] calldata riskParams, int256[8] calldata minRiskParamValues, int256[8] calldata maxRiskParamValues)',
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
//                                    createPerpetual
// ===============================================================================================
// console.log(
//   OperatorProxy.encodeFunctionData("createPerpetual", [
//     '0xe44287a9ee676e92e7687c28bb30ac6b5cb80bb2', // just test pool
//     '0x6ee936BdBD329063E8CE1d13F42eFEf912E85221', // BTC
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
