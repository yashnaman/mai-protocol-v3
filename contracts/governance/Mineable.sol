// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Stakeable.sol";

abstract contract IRewardDistributionRecipient is Ownable {
    address public rewardDistribution;

    function notifyRewardAmount(uint256 reward) virtual externalz;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address _rewardDistribution) external virtual onlyOwner {
        rewardDistribution = _rewardDistribution;
    }
}

contract Mineable is Stakeable, IRewardDistributionRecipient {
    IERC20 public rewardToken;

    uint256 public DURATION = 5 days;
    uint256 public starttime;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    function initialize(address tokenAddress) public {
        super.initialize(tokenAddress);
    }

    function deposits(address account) public view returns (uint256) {
        return _balances[account];
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, "MICUSDTPool: not start");
        _;
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

    function lastTimeRewardApplicable() public view returns (uint256) {}

    function rewardPerToken() public view returns (uint256) {}

    function earned(address account) public view returns (uint256) {}

    function exit() external {}

    function getReward() public updateReward(msg.sender) checkStart {}

    function notifyRewardAmount(uint256 reward)
        external
        override
        onlyRewardDistribution
        updateReward(address(0))
    {}

    //============================================
    uint256 public rewardPerBlock = 2;
    uint256 public startBlock;
    uint256 public endBlock;

    function setRewardPerBlock() public {}

    function updateEndTime() public {
        endBlock = rewardToken.balanceOf(this) / rewardPerBlock;

        entryRewardPerToken;
    }
}
