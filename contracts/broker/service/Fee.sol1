// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Fee is ReentrancyGuard {
    using SafeMath for uint256;

    uint256 internal _claimableFee;
    mapping(address => uint256) internal _balances;

    function deposit() external payable nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        Address.sendValue(payable(msg.sender), amount);
    }

    function _transfer(
        address spender,
        address recipient,
        uint256 gasAmount
    ) internal {
        require(_balances[spender] >= gasAmount, "");
        _balances[spender] = _balances[spender].sub(gasAmount);
        _balances[recipient] = _balances[recipient].add(gasAmount);
    }
}
