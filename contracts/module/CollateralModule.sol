// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

// import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

import "../interface/IFactory.sol";
import "../interface/IWETH.sol";

import "../Type.sol";

/**
 * @title   Collateral Module
 * @dev     Handle underlying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlying collateral
 *
 */
library CollateralModule {
    using SafeMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;

    // /**
    //  * @dev     Initialize collateral and decimals.
    //  * @param   collateral   Address of collateral, 0x0 if using ether.
    //  */

    /**
     * @notice  Try to retreive decimals from an erc20 contract.
     * @return  Decimals and true if success or 0 and false.ww
     */
    function retrieveDecimals(address token) internal view returns (uint8, bool) {
        (bool success, bytes memory result) = token.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (success && result.length >= 32) {
            return (abi.decode(result, (uint8)), success);
        }
        return (0, false);
    }

    /**
     * @dev     Get collateral balance in account.
     * @param   account     Address of account.
     * @return  Raw repesentation of collateral balance.
     */
    function collateralBalance(Core storage core, address account) internal view returns (int256) {
        return IERC20(core.collateral).balanceOf(account).toInt256();
    }

    /**
     * @dev     Transfer token from user if token is erc20 token.
     * @param   account     Address of account owner.
     * @param   amount   Amount of token to be transferred into contract.
     */
    function transferFromUser(
        Core storage core,
        address account,
        int256 amount,
        uint256 value
    ) internal {
        require(amount > 0, "amount is 0");
        uint256 rawAmount = _toRawAmount(core, amount.toUint256());
        if (core.isWrapped && value > 0) {
            IWETH(IFactory(core.factory).weth()).deposit();
        }
        IERC20(core.collateral).safeTransferFrom(account, address(this), rawAmount);
    }

    /**
     * @dev     Transfer token to user no matter erc20 token or ether.
     * @param   account     Address of account owner.
     * @param   amount   Amount of token to be transferred to user.
     */
    function transferToUser(
        Core storage core,
        address payable account,
        int256 amount
    ) internal {
        require(amount > 0, "amount is 0");
        uint256 rawAmount = _toRawAmount(core, amount.toUint256());
        if (core.isWrapped) {
            IWETH(IFactory(core.factory).weth()).withdraw(rawAmount);
            Address.sendValue(account, rawAmount);
        } else {
            IERC20(core.collateral).safeTransfer(account, rawAmount);
        }
    }

    /**
     * @dev     Convert the represention of amount from internal to raw.
     * @param   amount  Amount with internal decimals.
     * @return  Amount  with decimals of token.
     */
    function _toRawAmount(Core storage core, uint256 amount) private view returns (uint256) {
        return amount.div(core.scaler);
    }
}
