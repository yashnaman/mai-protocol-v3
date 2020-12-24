import BigNumber from 'bignumber.js';
import { ethers } from "hardhat";
import { expect } from "chai";

import "./helper";
import {
    createContract,
} from '../scripts/utils';

import { SymbolServiceFactory } from "../typechain/SymbolServiceFactory"

describe('SymbolService', () => {
    let symbolService;
    let accounts;

    beforeEach(async () => {
        symbolService = await createContract("SymbolService", [10000]);
        accounts = await ethers.getSigners();
    });

    describe('test whitelisted factory', function () {
        it('add and remove', async () => {
            const factory = accounts[1].address;
            expect(await symbolService.isWhitelistedFactory(factory)).to.be.false;
            await symbolService.addWhitelistedFactory(factory);
            expect(await symbolService.isWhitelistedFactory(factory)).to.be.true;
            await symbolService.removeWhitelistedFactory(factory);
            expect(await symbolService.isWhitelistedFactory(factory)).to.be.false;
        })
        it('not owner', async () => {
            const factory = accounts[1].address;
            const user = accounts[2];
            const symbolServiceUser = await SymbolServiceFactory.connect(symbolService.address, user);
            await expect(symbolServiceUser.addWhitelistedFactory(factory)).to.be.revertedWith('Ownable: caller is not the owner');
        })
    })

    describe('test assign normal symbol', function () {
        it('normal', async () => {




            const liquidityPool = accounts[1].address;
            await expect(symbolService.requestSymbol(liquidityPool, 0)).to.be.revertedWith('must called by contract');
        })

        it('not contract', async () => {
            const liquidityPool = accounts[1].address;
            await expect(symbolService.requestSymbol(liquidityPool, 0)).to.be.revertedWith('must called by contract');
        })
    })

})

