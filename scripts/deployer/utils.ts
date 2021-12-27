const chalk = require('chalk')

export function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export async function ensureFinished(transaction): Promise<any> {
    const result = await transaction;
    if (typeof result.deployTransaction != 'undefined') {
        return await result.deployTransaction.wait()
    } else {
        return await result.wait()
    }
}

export function printInfo(...message) {
    console.log(chalk.yellow("INFO "), ...message)
}

export function printError(...message) {
    console.log(chalk.red("ERRO "), ...message)
}