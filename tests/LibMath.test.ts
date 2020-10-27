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
  });

  it('Assigns initial balance', async () => {
    expect(await libMath.mostSignificantBit('0')).to.equal('0');
    expect(await libMath.mostSignificantBit('1')).to.equal('0');
    expect(await libMath.mostSignificantBit('2')).to.equal('1');
    expect(await libMath.mostSignificantBit('3')).to.equal('1');
    expect(await libMath.mostSignificantBit('4')).to.equal('2');
    expect(await libMath.mostSignificantBit('7')).to.equal('2');
    expect(await libMath.mostSignificantBit('8')).to.equal('3');
  });
});
