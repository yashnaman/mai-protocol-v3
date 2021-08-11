// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./KeeperWhitelist.sol";
import "./PoolCreatorV2.sol";

contract PoolCreator is PoolCreatorV2 {
    bool public override isUniverseSettled;
    address public guardian;

    event SetGuardian(address indexed oldGuardian, address indexed newGuardian);
    event SetUniverseSettled(bool isUniverseSettled);

    modifier onlyGuardian() {
        require(_msgSender() == guardian, "sender is not guardian");
        _;
    }

    /**
     * @notice  Set the guardian who is able to set `isUniverseSettled` flag.
     */
    function setGuardian(address guardian_) external onlyOwner {
        require(guardian_ != address(0), "guardian is zero address");
        require(guardian != guardian_, "guardian is already set");
        emit SetGuardian(guardian, guardian_);
        guardian = guardian_;
    }

    /**
     * @notice  Renounce guardian.
     */
    function renounceGuardian() external onlyGuardian {
        emit SetGuardian(guardian, address(0));
        guardian = address(0);
    }

    /**
     * @notice  Indicates the universe settle state.
     *          If the flag set to true:
     *              - all the perpetual created by this poolCreator can be settled immediately;
     *              - all the trading method will be unavailable.
     */
    function setUniverseSettled(bool isUniverseSettled_) external onlyGuardian {
        require(isUniverseSettled != isUniverseSettled_, "state is not changed");
        isUniverseSettled = isUniverseSettled_;
        emit SetUniverseSettled(isUniverseSettled_);
    }
}
