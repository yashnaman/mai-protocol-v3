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

    /**
     * @notice Get the available pool cash of the liquidity pool excluding specific perpetual
     * @param liquidityPool The liquidity pool
     * @param exclusiveIndex The index of perpetual to exclude, set to liquidityPool.perpetuals.length to skip excluding.
     * @return availablePoolCash The available pool cash of the liquidity pool excluding specific perpetual
     */
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

    /**
     * @notice Get the available pool cash of the liquidity pool
     * @param liquidityPool The liquidity pool
     * @return availablePoolCash The available pool cash of the liquidity pool
     */
    function getAvailablePoolCash(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256 availablePoolCash)
    {
        return getAvailablePoolCash(liquidityPool, liquidityPool.perpetuals.length);
    }

    /**
     * @notice Check if amm is maintenance safe in the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return isSafe If amm is maintenance safe in the perpetual
     */
    function isAMMMaintenanceMarginSafe(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex
    ) public returns (bool isSafe) {
        rebalance(liquidityPool, perpetualIndex);
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        isSafe = liquidityPool.perpetuals[perpetualIndex].isMaintenanceMarginSafe(
            address(this),
            perpetual.getMarkPrice()
        );
    }

    /**
     * @notice Initialize the liquidity pool, admin interface
     * @param liquidityPool The liquidity pool
     * @param collateral The collateral's address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of liquidity pool
     * @param operator The operator's address of liquidity pool
     * @param governor The governor's address of liquidity pool
     * @param shareToken The share token's address of liquidity pool
     * @param isFastCreationEnabled If the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     */
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
        liquidityPool.creator = msg.sender;
        IPoolCreator creator = IPoolCreator(liquidityPool.creator);
        liquidityPool.isWrapped = (collateral == creator.weth());
        liquidityPool.vault = creator.vault();
        liquidityPool.vaultFeeRate = creator.vaultFeeRate();
        liquidityPool.accessController = creator.accessController();

        liquidityPool.operator = operator;
        liquidityPool.shareToken = shareToken;
        liquidityPool.isFastCreationEnabled = isFastCreationEnabled;
    }

    /**
     * @notice Create and initialize new perpetual in the liquidity pool
     * @param liquidityPool The liquidity pool
     * @param oracle The oracle's address of the perpetual
     * @param coreParams The core parameters of the perpetual
     * @param riskParams The risk parameters of the perpetual, must between minimum value and maximum value
     * @param minRiskParamValues The risk parameters' minimum values of the perpetual
     * @param maxRiskParamValues The risk parameters' maximum values of the perpetual
     */
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
            ISymbolService(IPoolCreator(liquidityPool.creator).symbolService());
        service.allocateSymbol(address(this), perpetualIndex);
        if (liquidityPool.isRunning) {
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

    /**
     * @notice Run the liquidity pool, the operator can create new perpetual before running
     *         or after running if isFastCreationEnabled is set to true
     * @param liquidityPool The liquidity pool
     */
    function runLiquidityPool(LiquidityPoolStorage storage liquidityPool) public {
        uint256 length = liquidityPool.perpetuals.length;
        require(length > 0, "there should be at least 1 perpetual to run");
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].setNormalState();
        }
        liquidityPool.isRunning = true;
        emit RunLiquidityPool();
    }

    /**
     * @notice Set the parameter of the liquidity pool
     * @param liquidityPool The liquidity pool
     * @param key The key of the parameter
     * @param newValue The new value of the parameter
     */
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

    /**
     * @notice Set the base parameter of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of perpetual in the liquidity pool
     * @param key The key of the base parameter
     * @param newValue The new value of the base parameter
     */
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

    /**
     * @notice Set the risk parameter of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param key The key of the risk parameter
     * @param newValue The new value of the risk parameter, must between minimum value and maximum value
     * @param minValue The minimum value of the risk parameter
     * @param maxValue The maximum value of the risk parameter
     */
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

    /**
     * @notice Set the state of the perpetual to "emergency", must rebalance first
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function setEmergencyState(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex)
        public
    {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        rebalance(liquidityPool, perpetualIndex);
        liquidityPool.perpetuals[perpetualIndex].setEmergencyState();
    }

    /**
     * @notice Set the state of the perpetual to "cleared",
     *         call this method only when all active accounts is cleared
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
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

    /**
     * @notice Update the risk parameter of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param key The key of the risk parameter
     * @param newValue The new value of the risk perpetual, must be valid and between
     *                 minimum value and maximum value
     */
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

    /**
     * @notice Transfer the ownership of the liquidity pool to the new operator, call claimOperator()
     *         next to complete the action
     * @param liquidityPool The liquidity pool
     * @param newOperator The address of the new operator
     */
    function transferOperator(LiquidityPoolStorage storage liquidityPool, address newOperator)
        public
    {
        require(newOperator != address(0), "new operator is invalid");
        require(newOperator != liquidityPool.operator, "cannot transfer to current operator");
        liquidityPool.transferringOperator = newOperator;
        emit TransferOperatorTo(newOperator);
    }

    /**
     * @notice Claim the ownership of the liquidity pool to the claimer,
     *         the claimer must be transferred the ownership before
     * @param liquidityPool The liquidity pool
     * @param claimer The address of claimer
     */
    function claimOperator(LiquidityPoolStorage storage liquidityPool, address claimer) public {
        require(
            claimer == liquidityPool.transferringOperator,
            "claimer must be specified by operator"
        );
        liquidityPool.operator = claimer;
        liquidityPool.transferringOperator = address(0);
        // update record in Tracer.sol
        IPoolCreator(liquidityPool.creator).setLiquidityPoolOwnership(address(this), claimer);
        emit ClaimOperatorTo(claimer);
    }

    /**
     * @notice Revoke the operator of the liquidity pool
     * @param liquidityPool The liquidity pool
     */
    function revokeOperator(LiquidityPoolStorage storage liquidityPool) public {
        liquidityPool.operator = address(0);
        emit RevokeOperator();
    }

    /**
     * @notice Update the funding state of each perpetual of the liquidity pool
     * @param liquidityPool The liquidity pool
     * @param currentTime The current timestamp
     */
    function updateFundingState(LiquidityPoolStorage storage liquidityPool, uint256 currentTime)
        public
    {
        if (liquidityPool.fundingTime >= currentTime) {
            // invalid time
            return;
        }
        int256 timeElapsed = currentTime.sub(liquidityPool.fundingTime).toInt256();
        uint256 length = liquidityPool.perpetuals.length;
        for (uint256 i = 0; i < length; i++) {
            liquidityPool.perpetuals[i].updateFundingState(timeElapsed);
        }
        liquidityPool.fundingTime = currentTime;
    }

    /**
     * @notice Update the funding rate of each perpetual of the liquidity pool
     * @param liquidityPool The liquidity pool
     */
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

    /**
     * @notice Update the oracle price of each perpetual of the liquidity pool
     * @param liquidityPool The liquidity pool
     * @param currentTime The current timestamp
     */
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

    /**
     * @notice Donate collateral to the insurance fund of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param amount The amount of collateral to donate
     */
    function donateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        int256 totalAmount = liquidityPool.transferFromUser(msg.sender, amount);
        liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(totalAmount);
    }

    /**
     * @notice Deposit collateral to the trader's account of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The amount of collateral to deposit
     */
    function deposit(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        int256 totalAmount = liquidityPool.transferFromUser(trader, amount);
        if (liquidityPool.perpetuals[perpetualIndex].deposit(trader, totalAmount)) {
            IPoolCreator(liquidityPool.creator).activatePerpetualFor(trader, perpetualIndex);
        }
    }

    /**
     * @notice Withdraw collateral from the trader's account of the perpetual
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @param amount The amount of collateral to withdraw
     */
    function withdraw(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        rebalance(liquidityPool, perpetualIndex);
        if (liquidityPool.perpetuals[perpetualIndex].withdraw(trader, amount)) {
            IPoolCreator(liquidityPool.creator).deactivatePerpetualFor(trader, perpetualIndex);
        }
        liquidityPool.transferToUser(payable(trader), amount);
    }

    /**
     * @notice Settle the trader's account of the perpetual and send the trader the left collateral
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     */
    function settle(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        require(trader != address(0), "trader is invalid");
        int256 marginToReturn = liquidityPool.perpetuals[perpetualIndex].settle(trader);
        liquidityPool.transferToUser(payable(trader), marginToReturn);
    }

    /**
     * @notice Clear the next active account of the perpetual which state is "emergency" and send
     *         gas reward of collateral to msg.sender. If all active accounts are cleared,
     *         the perpetual's state will change to "cleared"
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
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

    /**
     * @notice Add collateral to the liquidity pool and get the minted share token
     * @param liquidityPool The liquidity pool
     * @param trader The address of trader that adding liquidity
     * @param cashToAdd The cash to add
     */
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

    /**
     * @notice Remove collateral from the liquidity pool and redeem the share token
     * @param liquidityPool The liquidity pool
     * @param trader The address of the trader that removing liquidity
     * @param shareToRemove The amount of the share token to redeem
     */
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

    /**
     * @notice Increase the claimable fee(collateral) of the account
     * @param liquidityPool The liquidity pool
     * @param account The address of account
     * @param amount The amount of fee to increase
     */
    function increaseFee(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        liquidityPool.claimableFees[account] = liquidityPool.claimableFees[account].add(amount);
        emit IncreaseFee(account, amount);
    }

    /**
     * @notice Claim claimable fee(collateral) of the claimer
     * @param liquidityPool The liquidity pool
     * @param claimer The address of claimer
     * @param amount The amount of fee(collateral) to claim
     */
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

    /**
     * @notice To keep the amm's margin equal to initial margin in the perpetual as posiible,
     *         transfer collateral between the perpetual and the liquidity pool's cash, then
     *         update the amm's cash in perpetual. The liquidity pool's cash can be negative,
     *         but the available cash can't. If amm need to transfer and the available cash
     *         is not enough, transfer all the rest available cash of collateral
     * @param liquidityPool The liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function rebalance(LiquidityPoolStorage storage liquidityPool, uint256 perpetualIndex) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        if (perpetual.state != PerpetualState.NORMAL) {
            return;
        }
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
                // pool has no more collateral, nothing to rebalance
                return;
            }
            rebalanceMargin = rebalanceMargin.abs().min(availablePoolCash);
            perpetual.updateCash(address(this), rebalanceMargin);
            perpetual.increaseTotalCollateral(rebalanceMargin);
            decreasePoolCash(liquidityPool, rebalanceMargin);
        }
    }

    /**
     * @notice Increase the liquidity pool's cash
     * @param liquidityPool The liquidity pool
     * @param amount The amount of collateral to increase
     */
    function increasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.add(amount);
    }

    /**
     * @notice Decrease the liquidity pool's cash
     * @param liquidityPool The liquidity pool
     * @param amount The amount of collateral to decrease
     */
    function decreasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        liquidityPool.poolCash = liquidityPool.poolCash.sub(amount);
    }

    /**
     * @notice Check if the trader is authorized by the grantor. Any trader is authorized if the
     *         grantor is himself
     * @param liquidityPool The liquidity pool
     * @param trader The address of the trader
     * @param grantor The address of the grantor
     * @param privilege The privilege
     * @return isGranted If the trader is authorized
     */
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
