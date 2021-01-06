// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../interface/IAccessControll.sol";
import "../interface/IPoolCreator.sol";
import "../interface/IShareToken.sol";
import "../interface/ISymbolService.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";

import "./AMMModule.sol";
import "./CollateralModule.sol";
import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";
import "./SignatureModule.sol";

import "../Type.sol";

import "hardhat/console.sol";

library LiquidityPoolModule {
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using SignatureModule for bytes32;

    using AMMModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    event AddLiquidity(address trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address trader, int256 returnedCash, int256 burnedShare);
    event IncreaseFee(address recipient, int256 amount);
    event ClaimFee(address claimer, int256 amount);
    event UpdatePoolMargin(int256 poolMargin);
    event TransferOperatorTo(address newOperator);
    event ClaimOperatorTo(address newOperator);
    event RevokeOperator();
    event SetLiquidityPoolParameter(bytes32 key, int256 value);
    event CreatePerpetual(
        uint256 perpetualIndex,
        address governor,
        address shareToken,
        address operator,
        address oracle,
        address collateral,
        int256[9] coreParams,
        int256[6] riskParams
    );
    event RunLiquidityPool();

    function getAvailablePoolCash(
        LiquidityPoolStorage storage liquidityPool,
        uint256 exclusiveIndex
    ) public view returns (int256 availablePoolCash) {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            if (i == exclusiveIndex || perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            int256 markPrice = perpetual.getMarkPrice();
            availablePoolCash = availablePoolCash.add(
                perpetual.getMargin(address(this), markPrice).sub(
                    perpetual.getInitialMargin(address(this), markPrice)
                )
            );
        }
        return availablePoolCash.add(liquidityPool.poolCash);
    }

    function getAvailablePoolCash(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256 availablePoolCash)
    {
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            PerpetualStorage storage perpetual = liquidityPool.perpetuals[i];
            if (perpetual.state != PerpetualState.NORMAL) {
                continue;
            }
            int256 markPrice = perpetual.getMarkPrice();
            availablePoolCash = availablePoolCash.add(
                perpetual.getMargin(address(this), markPrice).sub(
                    perpetual.getInitialMargin(address(this), markPrice)
                )
            );
        }
        return availablePoolCash.add(liquidityPool.poolCash);
    }

    function isAMMMarginSafe(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        public
        returns (bool isSafe)
    {
        rebalance(liquidityPool, perpetualIndex);
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        isSafe = liquidityPool.perpetuals[perpetualIndex].isMarginSafe(
            address(this),
            perpetual.getMarkPrice()
        );
    }

    // admin interface
    function initialize(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        uint256 collateralDecimals,
        address operator,
        address governor,
        address shareToken,
        bool isFastCreationEnabled
    ) public {
        require(collateral != address(0), "collateral is invalid");
        require(governor != address(0), "governor is invalid");
        require(shareToken != address(0), "shareToken is invalid");

        liquidityPool.initializeCollateral(collateral, collateralDecimals);
        liquidityPool.factory = msg.sender;
        IPoolCreator factory = IPoolCreator(liquidityPool.factory);
        liquidityPool.isWrapped = (collateral == factory.weth());
        liquidityPool.vault = factory.vault();
        liquidityPool.vaultFeeRate = factory.vaultFeeRate();
        liquidityPool.accessController = factory.accessController();

        liquidityPool.operator = operator;
        liquidityPool.shareToken = shareToken;
        liquidityPool.isFastCreationEnabled = isFastCreationEnabled;
    }

    function createPerpetual(
        LiquidityPoolStorage storage liquidityPool,
        address oracle,
        int256[9] calldata coreParams,
        int256[6] calldata riskParams,
        int256[6] calldata minRiskParamValues,
        int256[6] calldata maxRiskParamValues
    ) public {
        uint256 perpetualIndex = liquidityPool.perpetuals.length;
        PerpetualStorage storage perpetual = liquidityPool.perpetuals.push();
        perpetual.initialize(
            perpetualIndex,
            oracle,
            coreParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
        ISymbolService service =
            ISymbolService(IPoolCreator(liquidityPool.factory).symbolService());
        service.allocateSymbol(address(this), perpetualIndex);
        if (liquidityPool.isInitialized) {
            perpetual.setNormalState();
        }
        emit CreatePerpetual(
            perpetualIndex,
            liquidityPool.governor,
            liquidityPool.shareToken,
            liquidityPool.operator,
            oracle,
            liquidityPool.collateralToken,
            coreParams,
            riskParams
        );
    }

    function runLiquidityPool(LiquidityPoolStorage storage liquidityPool) public {
        uint256 length = liquidityPool.perpetuals.length;
        require(length > 0, "there should be at least 1 perpetual to run");
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].setNormalState();
        }
        liquidityPool.isInitialized = true;
        emit RunLiquidityPool();
    }

    function setLiquidityPoolParameter(
        LiquidityPoolStorage storage liquidityPool,
        bytes32 key,
        int256 newValue
    ) public {
        if (key == "isFastCreationEnabled") {
            liquidityPool.isFastCreationEnabled = (newValue != 0);
        } else {
            revert("key not found");
        }
        emit SetLiquidityPoolParameter(key, newValue);
    }

    function setPerpetualBaseParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.setBaseParameter(key, newValue);
        perpetual.validateBaseParameters();
    }

    function setPerpetualRiskParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue,
        int256 minValue,
        int256 maxValue
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.setRiskParameter(key, newValue, minValue, maxValue);
        perpetual.validateRiskParameters();
    }

    function setEmergencyState(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        public
    {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        rebalance(liquidityPool, perpetualIndex);
        liquidityPool.perpetuals[perpetualIndex].setEmergencyState();
    }

    function setClearedState(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        public
    {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.countMargin(address(this));
        perpetual.setClearedState();
        int256 marginToReturn = perpetual.settle(address(this));
        increasePoolCash(liquidityPool, marginToReturn);
    }

    function updatePerpetualRiskParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        bytes32 key,
        int256 newValue
    ) external {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateRiskParameter(key, newValue);
        perpetual.validateRiskParameters();
    }

    function transferOperator(LiquidityPoolStorage storage liquidityPool, address newOperator)
        public
    {
        require(newOperator != address(0), "new operator is invalid");
        liquidityPool.transferringOperator = newOperator;
        emit TransferOperatorTo(newOperator);
    }

    function claimOperator(LiquidityPoolStorage storage liquidityPool, address claimer) public {
        require(
            claimer == liquidityPool.transferringOperator,
            "claimer must be specified by operator"
        );
        liquidityPool.operator = claimer;
        liquidityPool.transferringOperator = address(0);
        emit ClaimOperatorTo(claimer);
    }

    function revokeOperator(LiquidityPoolStorage storage liquidityPool) public {
        liquidityPool.operator = address(0);
        emit RevokeOperator();
    }

    // state
    function updateFundingState(LiquidityPoolStorage storage liquidityPool, uint256 currentTime)
        public
    {
        if (liquidityPool.fundingTime >= currentTime) {
            return;
        }
        int256 timeElapsed = currentTime.sub(liquidityPool.fundingTime).toInt256();
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updateFundingState(timeElapsed);
        }
        liquidityPool.fundingTime = currentTime;
    }

    function updateFundingRate(LiquidityPoolStorage storage liquidityPool) public {
        AMMModule.Context memory context = liquidityPool.prepareContext();
        (int256 poolMargin, bool isAMMSafe) = AMMModule.getPoolMargin(context);
        emit UpdatePoolMargin(poolMargin);
        if (!isAMMSafe) {
            poolMargin = 0;
        }
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updateFundingRate(poolMargin);
        }
    }

    function updatePrice(LiquidityPoolStorage storage liquidityPool, uint256 currentTime) public {
        if (liquidityPool.priceUpdateTime >= currentTime) {
            return;
        }
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updatePrice();
        }
        liquidityPool.priceUpdateTime = currentTime;
    }

    function donateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        int256 totalAmount = liquidityPool.transferFromUser(msg.sender, amount);
        liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(totalAmount);
    }

    function deposit(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        int256 totalAmount = liquidityPool.transferFromUser(trader, amount);
        if (liquidityPool.perpetuals[perpetualIndex].deposit(trader, totalAmount)) {
            IPoolCreator(liquidityPool.factory).activateLiquidityPoolFor(trader, perpetualIndex);
        }
    }

    function withdraw(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        rebalance(liquidityPool, perpetualIndex);
        if (liquidityPool.perpetuals[perpetualIndex].withdraw(trader, amount)) {
            IPoolCreator(liquidityPool.factory).deactivateLiquidityPoolFor(trader, perpetualIndex);
        }
        liquidityPool.transferToUser(payable(trader), amount);
    }

    function settle(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        require(trader != address(0), "trader is invalid");
        int256 marginToReturn = liquidityPool.perpetuals[perpetualIndex].settle(trader);
        liquidityPool.transferToUser(payable(trader), marginToReturn);
    }

    function clear(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        if (
            perpetual.keeperGasReward > 0 && perpetual.totalCollateral >= perpetual.keeperGasReward
        ) {
            perpetual.decreaseTotalCollateral(perpetual.keeperGasReward);
            liquidityPool.transferToUser(payable(msg.sender), perpetual.keeperGasReward);
        }
        if (perpetual.clear(perpetual.getNextActiveAccount())) {
            setClearedState(liquidityPool, perpetualIndex);
        }
    }

    function addLiquidity(
        LiquidityPoolStorage storage liquidityPool,
        address trader,
        int256 cashToAdd
    ) public {
        require(cashToAdd > 0 || msg.value > 0, "cash amount must be positive");
        int256 totalCashToAdd = liquidityPool.transferFromUser(trader, cashToAdd);
        IShareToken shareToken = IShareToken(liquidityPool.shareToken);
        int256 shareTotalSupply = shareToken.totalSupply().toInt256();

        int256 shareToMint = liquidityPool.getShareToMint(shareTotalSupply, totalCashToAdd);
        require(shareToMint > 0, "received share must be positive");
        liquidityPool.poolCash = liquidityPool.poolCash.add(totalCashToAdd);
        shareToken.mint(trader, shareToMint.toUint256());
        emit AddLiquidity(trader, totalCashToAdd, shareToMint);
    }

    function removeLiquidity(
        LiquidityPoolStorage storage liquidityPool,
        address trader,
        int256 shareToRemove
    ) public {
        require(shareToRemove > 0, "share to remove must be positive");
        IShareToken shareToken = IShareToken(liquidityPool.shareToken);
        require(
            shareToRemove.toUint256() <= shareToken.balanceOf(trader),
            "insufficient share balance"
        );
        int256 shareTotalSupply = shareToken.totalSupply().toInt256();
        int256 cashToReturn = liquidityPool.getCashToReturn(shareTotalSupply, shareToRemove);
        require(cashToReturn >= 0, "cash to return is negative");
        require(cashToReturn <= getAvailablePoolCash(liquidityPool), "insufficient pool cash");

        shareToken.burn(trader, shareToRemove.toUint256());
        liquidityPool.transferToUser(payable(trader), cashToReturn);
        decreasePoolCash(liquidityPool, cashToReturn);
        emit RemoveLiquidity(trader, cashToReturn, shareToRemove);
    }

    function increaseFee(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        liquidityPool.claimableFees[account] = liquidityPool.claimableFees[account].add(amount);
        emit IncreaseFee(account, amount);
    }

    function claimFee(
        LiquidityPoolStorage storage liquidityPool,
        address claimer,
        int256 amount
    ) public {
        require(amount > 0, "invalid amount");
        require(amount <= liquidityPool.claimableFees[claimer], "insufficient fee");
        liquidityPool.claimableFees[claimer] = liquidityPool.claimableFees[claimer].sub(amount);
        liquidityPool.transferToUser(payable(claimer), amount);
        emit ClaimFee(claimer, amount);
    }

    function rebalance(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        int256 rebalanceMargin = perpetual.getRebalanceMargin();
        if (rebalanceMargin == 0) {
            // nothing to rebalance
            return;
        } else if (rebalanceMargin > 0) {
            // from perp to pool
            perpetual.updateCash(address(this), rebalanceMargin.neg());
            perpetual.decreaseTotalCollateral(rebalanceMargin);
            increasePoolCash(liquidityPool, rebalanceMargin);
        } else {
            // from pool to perp
            int256 availablePoolCash = getAvailablePoolCash(liquidityPool, perpetualIndex);
            if (availablePoolCash < 0) {
                return;
            }
            rebalanceMargin = rebalanceMargin.abs().min(availablePoolCash);
            perpetual.updateCash(address(this), rebalanceMargin);
            perpetual.increaseTotalCollateral(rebalanceMargin);
            decreasePoolCash(liquidityPool, rebalanceMargin);
        }
    }

    function increasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.add(amount);
    }

    function decreasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.sub(amount);
    }

    function isAuthorized(
        LiquidityPoolStorage storage liquidityPool,
        address trader,
        address grantor,
        uint256 privilege
    ) public view returns (bool isGranted) {
        isGranted =
            trader == grantor ||
            IAccessControll(liquidityPool.accessController).isGranted(trader, grantor, privilege);
    }
}
