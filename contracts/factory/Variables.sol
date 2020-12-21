// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract Variables {
    address internal _weth;
    address internal _symbolService;
    address internal _vault;
    int256 internal _vaultFeeRate;

    constructor(address wethToken, address symbolService, address globalVault, int256 globalVaultFeeRate) {
        require(wethToken != address(0), "invalid weth address");
        require(symbolService != address(0), "invalid weth address");
        require(globalVault != address(0), "invalid vault address");
        _weth = wethToken;
        _symbolService = symbolService;
        _vault = globalVault;
        _vaultFeeRate = globalVaultFeeRate;
    }

    function vault() public view returns (address) {
        return _vault;
    }

    function vaultFeeRate() public view returns (int256) {
        return _vaultFeeRate;
    }

    function weth() public view returns (address) {
        return _weth;
    }

    function accessController() public view returns (address) {
        return address(this);
    }

    function symbolService() public view returns (address) {
        return _symbolService;
    }
}
