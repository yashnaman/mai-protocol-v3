// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract Variables {
    address internal _weth;
    address internal _symbolService;
    address internal _vault;
    int256 internal _vaultFeeRate;

    event SetVaultFeeRate(int256 prevFeeRate, int256 newFeeRate);

    constructor(
        address wethToken_,
        address symbolService_,
        address vault_,
        int256 vaultFeeRate_
    ) {
        require(wethToken_ != address(0), "invalid weth address");
        require(symbolService_ != address(0), "invalid weth address");
        require(vault_ != address(0), "invalid vault address");
        require(vaultFeeRate_ >= 0, "negative vault fee rate");

        _weth = wethToken_;
        _symbolService = symbolService_;
        _vault = vault_;
        _vaultFeeRate = vaultFeeRate_;
    }

    /**
     * @notice Get the address of the vault
     * @return address The address of the vault
     */
    function getVault() public view returns (address) {
        return _vault;
    }

    /**
     * @notice Get the vault fee rate
     * @return int256 The vault fee rate
     */
    function getVaultFeeRate() public view returns (int256) {
        return _vaultFeeRate;
    }

    function setVaultFeeRate(int256 newVaultFeeRate) public {
        require(msg.sender == _vault, "caller must be vault");
        require(newVaultFeeRate >= 0, "negative vault fee rate");
        require(newVaultFeeRate != _vaultFeeRate, "unchanged vault fee rate");

        emit SetVaultFeeRate(_vaultFeeRate, newVaultFeeRate);
        _vaultFeeRate = newVaultFeeRate;
    }

    /**
     * @notice Get the address of weth
     * @return address The address of weth
     */
    function getWeth() public view returns (address) {
        return _weth;
    }

    /**
     * @notice Get the address of the access controller, it's always itself
     * @return address The address of the access controller
     */
    function getAccessController() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Get the address of the symbol service
     * @return address The address of the symbol service
     */
    function getSymbolService() public view returns (address) {
        return _symbolService;
    }
}
