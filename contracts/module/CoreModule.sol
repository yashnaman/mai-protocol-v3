// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/Error.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";

import "../Type.sol";
import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./MarketModule.sol";
import "./SettlementModule.sol";

library CoreModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using CollateralModule for Core;

    event DonateInsuranceFund(address trader, int256 amount);
    event IncreaseClaimableFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);

    function donateInsuranceFund(Core storage core, int256 amount) external {
        require(amount > 0, "amount is 0");
        core.transferFromUser(msg.sender, amount);
        core.donatedInsuranceFund = core.donatedInsuranceFund.add(amount);
        emit DonateInsuranceFund(msg.sender, amount);
    }

    function increaseClaimableFee(
        Core storage core,
        address recipient,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        core.claimableFees[recipient] = core.claimableFees[recipient].add(amount);
        core.totalClaimableFee = core.totalClaimableFee.add(amount);
        emit IncreaseClaimableFee(recipient, amount);
    }

    function claimFee(
        Core storage core,
        address claimer,
        int256 amount
    ) public {
        require(amount <= core.claimableFees[claimer], "insufficient fee");
        core.claimableFees[claimer] = core.claimableFees[claimer].sub(amount);
        core.totalClaimableFee = core.totalClaimableFee.sub(amount);
        core.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }
}
