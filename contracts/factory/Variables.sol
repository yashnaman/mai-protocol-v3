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

    /**
     * @notice Get address of vault
     * @return address The address of vault
     */
    function vault() public view returns (address) {
        return _vault;
    }

    /**
     * @notice Get vault fee rate
     * @return int256 The vault fee rate
     */
    function vaultFeeRate() public view returns (int256) {
        return _vaultFeeRate;
    }

    /**
     * @notice Get address of weth
     * @return address The address of weth
     */
    function weth() public view returns (address) {
        return _weth;
    }

    /**
     * @notice Get address of access controller
     * @return address The address of access controller
     */
    function accessController() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Get address of symbol service
     * @return address The address of symbol service
     */
    function symbolService() public view returns (address) {
        return _symbolService;
    }
}
