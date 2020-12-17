// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "../interface/IFactory.sol";
import "../interface/IDecimals.sol";

import "./OracleModule.sol";
import "./CollateralModule.sol";
import "./MarginModule.sol";
import "./PerpetualModule.sol";
import "./SettlementModule.sol";

import "../Type.sol";

library CoreModule {
    using SafeCastUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using CollateralModule for Core;
    using OracleModule for Core;
    using MarginModule for Perpetual;
    using OracleModule for Perpetual;

    uint256 internal constant MAX_COLLATERAL_DECIMALS = 18;

    event DonateInsuranceFund(address trader, int256 amount);
    event IncreaseClaimableFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);

    function donateInsuranceFund(Core storage core, int256 amount) external {
        int256 totalAmount = core.transferFromUser(msg.sender, amount);
        require(totalAmount > 0, "total amount is 0");
        core.donatedInsuranceFund = core.donatedInsuranceFund.add(totalAmount);
        emit DonateInsuranceFund(msg.sender, totalAmount);
    }

    function initialize(
        Core storage core,
        address collateral,
        address operator,
        address governor,
        address shareToken
    ) internal {
        require(collateral != address(0), "collateral is invalid");
        require(governor != address(0), "governor is invalid");
        require(shareToken != address(0), "shareToken is invalid");

        uint8 decimals = IDecimals(collateral).decimals();
        require(decimals <= MAX_COLLATERAL_DECIMALS, "collateral decimals is out of range");
        core.collateral = collateral;
        core.scaler = uint256(10**(MAX_COLLATERAL_DECIMALS.sub(uint256(decimals))));

        core.factory = msg.sender;
        IFactory factory = IFactory(core.factory);
        core.isWrapped = (collateral == factory.weth());
        core.vault = factory.vault();
        core.vaultFeeRate = factory.vaultFeeRate();
        core.accessController = factory.accessController();

        core.operator = operator;
        core.shareToken = shareToken;
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

    function rebalance(Core storage core, Perpetual storage perpetual) public {
        int256 rebalancingAmount = perpetual
            .initialMargin(address(this), perpetual.markPrice())
            .sub(perpetual.margin(address(this), perpetual.markPrice()));
        // pool => perpetual
        if (rebalancingAmount != 0) {
            core.poolCollateral = core.poolCollateral.sub(rebalancingAmount);
            perpetual.depositedCollateral = perpetual.depositedCollateral.add(rebalancingAmount);
        }
    }
}
