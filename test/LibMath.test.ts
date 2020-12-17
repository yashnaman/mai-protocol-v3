import { expect, use } from "chai";
import { waffleChai } from "@ethereum-waffle/chai";

import './helper';
import { createContract } from '../scripts/utils';

use(waffleChai);

describe('LibMath', () => {
    let libMath;

    beforeEach(async () => {
        libMath = await createContract("TestLibMath");
    });

    describe('mostSignificantBit', () => {
        it('normal', async () => {
            expect(await libMath.mostSignificantBit('0')).to.equal(0);
            expect(await libMath.mostSignificantBit('1')).to.equal(0);
            expect(await libMath.mostSignificantBit('2')).to.equal(1);
            expect(await libMath.mostSignificantBit('3')).to.equal(1);
            expect(await libMath.mostSignificantBit('4')).to.equal(2);
            expect(await libMath.mostSignificantBit('7')).to.equal(2);
            expect(await libMath.mostSignificantBit('8')).to.equal(3);
        });
    });

    describe('sqrt', () => {
        it('small', async () => {
            expect(await libMath.sqrt('0')).to.equal('0');
            expect(await libMath.sqrt('1')).to.equal('1');
            expect(await libMath.sqrt('2')).to.equal('1');
            expect(await libMath.sqrt('3')).to.equal('1');
            expect(await libMath.sqrt('4')).to.equal('2');
            expect(await libMath.sqrt('5')).to.equal('2');
            expect(await libMath.sqrt('6')).to.equal('2');
            expect(await libMath.sqrt('7')).to.equal('2');
            expect(await libMath.sqrt('8')).to.equal('2');
            expect(await libMath.sqrt('9')).to.equal('3');
        });

        it('normal', async () => {
            // 1e-9
            expect(await libMath.sqrt('1000000000000000000')).to.equal('1000000000');

            // 1
            expect(await libMath.sqrt('1000000000000000000000000000000000000')).to.equal('1000000000000000000');

            // 0.35
            expect(await libMath.sqrt('122500000000000000000000000000000000')).to.equal('350000000000000000');

            // 7e4
            expect(await libMath.sqrt('4900000000000000000000000000000000000000000000')).to.equal('70000000000000000000000');

            // 1e12
            expect(await libMath.sqrt('1000000000000000000000000000000000000000000000000000000000000')).to.equal('1000000000000000000000000000000');

            // -1
            await expect(libMath.sqrt('-1000000000000000000000000000000000000')).to.be.revertedWith('negative sqrt');

            // max num
            expect(await libMath.sqrt('57896044618658097711785492504343953926634992332820282019728792003956564819967')).to.equal('240615969168004511545033772477625056927');
        });
    });
});
