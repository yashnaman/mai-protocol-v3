// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./GovernorAlpha.sol";
import "./RewardDistribution.sol";

contract LpGovernor is
    Initializable,
    ContextUpgradeable,
    ERC20Upgradeable,
    GovernorAlpha,
    RewardDistribution
{
    // admin:  to mint/burn token
    address internal _minter;

    function initialize(
        string memory name,
        string memory symbol,
        address minter,
        address target,
        address rewardToken,
        address distributor
    ) public virtual initializer {
        __ERC20_init_unchained(name, symbol);
        __GovernorAlpha_init_unchained(target);
        __RewardDistribution_init_unchained(rewardToken, distributor);

        _minter = minter;
        _target = target;
    }

    function mint(address account, uint256 amount) public virtual {
        require(_msgSender() == _minter, "must be minter to mint");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual {
        require(_msgSender() == _minter, "must be minter to burn");
        _burn(account, amount);
    }

    function isLocked(address account) public virtual returns (bool) {
        return GovernorAlpha.isLockedByVoting(account);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override(ERC20Upgradeable, GovernorAlpha, RewardDistribution)
        returns (uint256)
    {
        return ERC20Upgradeable.balanceOf(account);
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC20Upgradeable, GovernorAlpha, RewardDistribution)
        returns (uint256)
    {
        return ERC20Upgradeable.totalSupply();
    }

    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(!isLocked(sender), "sender is locked");
        _updateReward(sender);
        super._beforeTokenTransfer(sender, recipient, amount);
    }

    bytes32[50] private __gap;
}
