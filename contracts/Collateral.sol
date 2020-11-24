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

import "./libraries/Constant.sol";
import "./Type.sol";

/**
 * @title   Collateral Module
 * @dev     Handle underlying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlying collateral
 *
 */
contract Collateral {
	using SafeMath for uint256;
	using SafeCast for int256;
	using SignedSafeMath for int256;
	using SafeERC20 for IERC20;

	uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

	// collateral
	uint256 internal _scaler;
	address internal _collateral;

	// /**
	//  * @dev     Initialize collateral and decimals.
	//  * @param   collateral   Address of collateral, 0x0 if using ether.
	//  */
	function _collateralInitialize(address collateral) internal {
		require(collateral != address(0), "collateral is invalid");
		(uint8 decimals, bool ok) = _retrieveDecimals(collateral);
		require(ok, "cannot read decimals");
		require(decimals <= MAX_COLLATERAL_DECIMALS, "decimals is out of range");
		_collateral = collateral;
		_scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));
	}

	/**
	 * @notice  Try to retreive decimals from an erc20 contract.
	 * @return  Decimals and true if success or 0 and false.ww
	 */
	function _retrieveDecimals(address token) internal view returns (uint8, bool) {
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
	function _collateralBalance(address account) internal view returns (uint256) {
		return IERC20(_collateral).balanceOf(account);
	}

	/**
	 * @dev     Transfer token from user if token is erc20 token.
	 * @param   account     Address of account owner.
	 * @param   amount   Amount of token to be transferred into contract.
	 */
	function _transferFromUser(address account, int256 amount) internal {
		require(amount > 0, "amount is 0");
		uint256 rawAmount = _toRawAmount(amount.toUint256());
		IERC20(_collateral).safeTransferFrom(account, address(this), rawAmount);
	}

	/**
	 * @dev     Transfer token to user no matter erc20 token or ether.
	 * @param   account     Address of account owner.
	 * @param   amount   Amount of token to be transferred to user.
	 */
	function _transferToUser(address payable account, int256 amount) internal {
		require(amount > 0, "amount is 0");
		uint256 rawAmount = _toRawAmount(amount.toUint256());
		IERC20(_collateral).safeTransfer(account, rawAmount);
	}

	/**
	 * @dev     Convert the represention of amount from internal to raw.
	 * @param   amount  Amount with internal decimals.
	 * @return  Amount  with decimals of token.
	 */
	function _toRawAmount(uint256 amount) private view returns (uint256) {
		return amount.div(_scaler);
	}

	bytes32[50] private __gap;
}
