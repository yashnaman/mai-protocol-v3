// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./Stakeable.sol";

abstract contract IRewardDistributionRecipient is OwnableUpgradeable {
    address public rewardDistribution;

    function notifyRewardAmount(uint256 reward) external virtual;

    function setRewardRate(uint256 _rewardRate) external virtual;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address _rewardDistribution) external virtual onlyOwner {
        rewardDistribution = _rewardDistribution;
    }
}

contract Mineable is Stakeable, IRewardDistributionRecipient {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public rewardToken;

    uint256 public DURATION = 5 days;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event RewardRateChanged(uint256 previousRate, uint256 currentRate);
    event RewardPaid(address indexed user, uint256 reward);

    function initialize(address tokenAddress, address rewardTokenAddress) public {
        super.initialize(tokenAddress);
        rewardToken = IERC20Upgradeable(rewardTokenAddress);
    }

    function deposits(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public override updateReward(msg.sender) {
        super.stake(amount);
    }

    function withdraw(uint256 amount) public override updateReward(msg.sender) {
        super.withdraw(amount);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp <= periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(
                    totalSupply()
                )
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 newRewardRate)
        external
        virtual
        override
        onlyRewardDistribution
        updateReward(address(0))
    {
        if (newRewardRate == 0) {
            periodFinish = block.timestamp;
        } else {
            periodFinish = periodFinish.sub(block.timestamp).mul(rewardRate).div(newRewardRate);
        }
        emit RewardRateChanged(rewardRate, newRewardRate);
        rewardRate = newRewardRate;
    }

    function notifyRewardAmount(uint256 reward)
        external
        virtual
        override
        onlyRewardDistribution
        updateReward(address(0))
    {
        uint256 period = reward.mul(10**18).div(rewardRate);
        // already finished or not initialized
        if (block.timestamp > periodFinish) {
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(period);
            emit RewardAdded(reward);
        } else {
            // not finished or not initialized
            periodFinish = periodFinish.add(period);
            emit RewardAdded(reward);
        }
    }
}
