import {Contract} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import LibMath from '../build/TestLibMath.json';

use(solidity);

describe('LibMath', () => {
  const [wallet, walletTo] = new MockProvider().getWallets();
  let libMath: Contract;

  beforeEach(async () => {
    libMath = await deployContract(wallet, LibMath);
  });

  describe('mostSignificantBit', () => {
    it('normal', async () => {
      expect(await libMath.mostSignificantBit('0')).to.equal('0');
      expect(await libMath.mostSignificantBit('1')).to.equal('0');
      expect(await libMath.mostSignificantBit('2')).to.equal('1');
      expect(await libMath.mostSignificantBit('3')).to.equal('1');
      expect(await libMath.mostSignificantBit('4')).to.equal('2');
      expect(await libMath.mostSignificantBit('7')).to.equal('2');
      expect(await libMath.mostSignificantBit('8')).to.equal('3');
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
      expect(await libMath.mostSignificantBit('1000000000000000000000000000000000000')).to.equal('1000000000000000000');

      // 0.35
      expect(await libMath.mostSignificantBit('122500000000000000000000000000000000')).to.equal('350000000000000000');

      // 7e4
      expect(await libMath.mostSignificantBit('4900000000000000000000000000000000000000000000')).to.equal('70000000000000000000000');

      // 1e12
      expect(await libMath.mostSignificantBit('1000000000000000000000000000000000000000000000000000000000000')).to.equal('1000000000000000000000000000000');
    });
  });
});
