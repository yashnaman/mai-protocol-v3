// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract Stakeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    event Stake(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    function initialize(address tokenAddress) public {
        token = IERC20(tokenAddress);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        require(amount > 0, "cannot stake zero amount");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount > 0, "cannot withdraw zero amount");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        token.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}
