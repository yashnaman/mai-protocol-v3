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

import "../Type.sol";

library LiquidityPoolModule {
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    using AMMModule for LiquidityPoolStorage;
    using CollateralModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using AMMModule for LiquidityPoolStorage;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    uint256 public constant OPERATOR_CHECK_IN_TIMEOUT = 10 days;

    event AddLiquidity(address indexed trader, int256 addedCash, int256 mintedShare);
    event RemoveLiquidity(address indexed trader, int256 returnedCash, int256 burnedShare);
    event IncreaseFee(address indexed recipient, int256 amount);
    event ClaimFee(address indexed claimer, int256 amount);
    event UpdatePoolMargin(int256 poolMargin);
    event TransferOperatorTo(address indexed newOperator);
    event ClaimOperator(address indexed newOperator);
    event RevokeOperator();
    event SetLiquidityPoolParameter(int256[1] value);
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
    event OperatorCheckIn(address indexed operator);

    /**
     * @dev Get the vault's address of the liquidity pool
     * @param liquidityPool The liquidity pool object
     * @return vault The vault's address of the liquidity pool
     */
    function getVault(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (address vault)
    {
        vault = IPoolCreator(liquidityPool.creator).getVault();
    }

    function getOperator(LiquidityPoolStorage storage liquidityPool)
        internal
        view
        returns (address operator)
    {
        return
            block.timestamp <= liquidityPool.operatorExpiration
                ? liquidityPool.operator
                : address(0);
    }

    /**
     * @dev Get the vault fee rate of the liquidity pool
     * @param liquidityPool The liquidity pool object
     * @return vaultFeeRate The vault fee rate of the liquidity pool
     */
    function getVaultFeeRate(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256 vaultFeeRate)
    {
        vaultFeeRate = IPoolCreator(liquidityPool.creator).getVaultFeeRate();
    }

    /**
     * @notice Get the available pool cash(collateral) of the liquidity pool excluding the specific perpetual. Available cash
     *         in a perpetual means: margin - initial margin
     * @param liquidityPool The liquidity pool object
     * @param exclusiveIndex The index of perpetual in the liquidity pool to exclude,
     *                       set to liquidityPool.perpetuals.length to skip excluding.
     * @return availablePoolCash The available pool cash(collateral) of the liquidity pool excluding the specific perpetual
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
     * @notice Get the available pool cash(collateral) of the liquidity pool. Sum of available cash of AMM in every perpetual
     *         in the liquidity pool, and add the pool cash
     * @param liquidityPool The liquidity pool object
     * @return availablePoolCash The available pool cash(collateral) of the liquidity pool
     */
    function getAvailablePoolCash(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256 availablePoolCash)
    {
        return getAvailablePoolCash(liquidityPool, liquidityPool.perpetuals.length);
    }

    /**
     * @notice Check if AMM is maintenance margin safe in the perpetual, need to rebalance before checking
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return isSafe True if AMM is maintenance margin safe in the perpetual
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
     * @notice Initialize the liquidity pool and set up its configuration
     * @param liquidityPool The liquidity pool object
     * @param collateral The collateral's address of the liquidity pool
     * @param collateralDecimals The collateral's decimals of the liquidity pool
     * @param operator The operator's address of the liquidity pool
     * @param governor The governor's address of the liquidity pool
     * @param shareToken The share token's address of the liquidity pool
     * @param isFastCreationEnabled True if the operator of the liquidity pool is allowed to create new perpetual
     *                              when the liquidity pool is running
     */
    function initialize(
        LiquidityPoolStorage storage liquidityPool,
        address creator,
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
        liquidityPool.creator = creator;
        IPoolCreator poolCreator = IPoolCreator(creator);
        liquidityPool.isWrapped = (collateral == poolCreator.getWeth());
        liquidityPool.accessController = poolCreator.getAccessController();

        liquidityPool.operator = operator;
        liquidityPool.operatorExpiration = block.timestamp.add(OPERATOR_CHECK_IN_TIMEOUT);
        liquidityPool.governor = governor;
        liquidityPool.shareToken = shareToken;
        liquidityPool.isFastCreationEnabled = isFastCreationEnabled;
    }

    /**
     * @notice Create and initialize new perpetual in the liquidity pool. Can only called by the operator
     *         if the liquidity pool is running or isFastCreationEnabled is set to true.
     *         Otherwise can only called by the governor
     * @param liquidityPool The liquidity pool object
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
            ISymbolService(IPoolCreator(liquidityPool.creator).getSymbolService());
        service.allocateSymbol(address(this), perpetualIndex);
        if (liquidityPool.isRunning) {
            perpetual.setNormalState();
        }
        emit CreatePerpetual(
            perpetualIndex,
            liquidityPool.governor,
            liquidityPool.shareToken,
            getOperator(liquidityPool),
            oracle,
            liquidityPool.collateralToken,
            coreParams,
            riskParams
        );
    }

    /**
     * @notice Run the liquidity pool. Can only called by the operator. The operator can create new perpetual before running
     *         or after running if isFastCreationEnabled is set to true
     * @param liquidityPool The liquidity pool object
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
     * @notice Set the parameter of the liquidity pool. Can only called by the governor
     * @param liquidityPool The liquidity pool object
     * @param params The new value of the parameter
     */
    function setLiquidityPoolParameter(
        LiquidityPoolStorage storage liquidityPool,
        int256[1] memory params
    ) public {
        liquidityPool.isFastCreationEnabled = (params[0] != 0);
        emit SetLiquidityPoolParameter(params);
    }

    function setPerpetualOracle(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address newOracle
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.setOracle(newOracle);
    }

    /**
     * @notice Set the base parameter of the perpetual. Can only called by the governor
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of perpetual in the liquidity pool
     * @param baseParams The new value of the base parameter
     */
    function setPerpetualBaseParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256[9] memory baseParams
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.setBaseParameter(baseParams);
    }

    /**
     * @notice Set the risk parameter of the perpetual, including minimum value and maximum value. Can only called by the governor
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of perpetual in the liquidity pool
     * @param riskParams The new value of the risk parameter, must between minimum value and maximum value
     * @param minRiskParamValues The minimum value of the risk parameter
     * @param maxRiskParamValues The maximum value of the risk parameter
     */
    function setPerpetualRiskParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256[6] memory riskParams,
        int256[6] memory minRiskParamValues,
        int256[6] memory maxRiskParamValues
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.setRiskParameter(riskParams, minRiskParamValues, maxRiskParamValues);
    }

    /**
     * @notice Set the risk parameter of the perpetual, including minimum value and maximum value. Can only called by the governor
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of perpetual in the liquidity pool
     * @param riskParams The new value of the risk parameter, must between minimum value and maximum value
     */
    function updatePerpetualRiskParameter(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256[6] memory riskParams
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateRiskParameter(riskParams);
    }

    /**
     * @notice Set the state of the perpetual to "EMERGENCY". Must rebalance first.
     *         Can only called when AMM is not maintenance margin safe in the perpetual.
     *         After that the perpetual is not allowed to trade, deposit and withdraw.
     *         The price of the perpetual is freezed to the settlement price
     * @param liquidityPool The liquidity pool object
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
     * @notice Set the state of the perpetual to "EMERGENCY". Must rebalance first.
     *         Can only called when AMM is not maintenance margin safe in the perpetual.
     *         After that the perpetual is not allowed to trade, deposit and withdraw.
     *         The price of the perpetual is freezed to the settlement price
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function setEmergencyState(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 settlementPrice
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        require(settlementPrice >= 0, "negative settlement price");
        liquidityPool.perpetuals[perpetualIndex].markPriceData = OraclePriceData({
            price: settlementPrice,
            time: block.timestamp
        });
        rebalance(liquidityPool, perpetualIndex);
        liquidityPool.perpetuals[perpetualIndex].setEmergencyState();
    }

    /**
     * @notice Set the state of the perpetual to "CLEARED". Add the collateral of AMM in the perpetual to the pool cash.
     *         Can only called when all the active accounts in the perpetual are cleared
     * @param liquidityPool The liquidity pool object
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
        transferFromPerpetualToPool(liquidityPool, perpetualIndex, marginToReturn);
    }

    /**
     * @notice Specify a new address to be operator. See transferOperator in Governance.sol.
     * @param  liquidityPool    The liquidity pool storage.
     * @param  newOperator      The address of new operator to transfer to
     */
    function transferOperator(LiquidityPoolStorage storage liquidityPool, address newOperator)
        public
    {
        require(newOperator != address(0), "new operator is invalid");
        require(newOperator != getOperator(liquidityPool), "cannot transfer to current operator");
        liquidityPool.transferringOperator = newOperator;
        emit TransferOperatorTo(newOperator);
    }

    function checkIn(LiquidityPoolStorage storage liquidityPool) public {
        liquidityPool.operatorExpiration = block.timestamp.add(OPERATOR_CHECK_IN_TIMEOUT);
        emit OperatorCheckIn(getOperator(liquidityPool));
    }

    /**
     * @notice  Claim the ownership of the liquidity pool to claimer. See `transferOperator` in Governance.sol.
     * @param   liquidityPool   The liquidity pool storage.
     * @param   claimer         The address of claimer
     */
    function claimOperator(LiquidityPoolStorage storage liquidityPool, address claimer) public {
        require(claimer == liquidityPool.transferringOperator, "caller is not qualified");
        liquidityPool.operator = claimer;
        liquidityPool.transferringOperator = address(0);
        IPoolCreator(liquidityPool.creator).setLiquidityPoolOwnership(address(this), claimer);
        emit ClaimOperator(claimer);
    }

    /**
     * @notice  Revoke operatorship of the liquidity pool.
     * @param   liquidityPool The liquidity pool object
     */
    function revokeOperator(LiquidityPoolStorage storage liquidityPool) public {
        liquidityPool.operator = address(0);
        IPoolCreator(liquidityPool.creator).setLiquidityPoolOwnership(address(this), address(0));
        emit RevokeOperator();
    }

    /**
     * @notice Update the funding state of each perpetual of the liquidity pool. Funding payment of every account in the
     *         liquidity pool is updated
     * @param liquidityPool The liquidity pool object
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
     * @param liquidityPool The liquidity pool object
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
     * @param liquidityPool The liquidity pool object
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
     * @notice Donate collateral to the insurance fund of the perpetual. Can improve the security of the perpetual.
     *         Can only called when the state of the perpetual is "NORMAL"
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param amount The amount of collateral to donate
     */
    function donateInsuranceFund(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address donator,
        int256 amount
    ) public {
        require(perpetualIndex < liquidityPool.perpetuals.length, "perpetual index out of range");
        int256 totalAmount =
            transferFromUserToPerpetual(liquidityPool, perpetualIndex, donator, amount);
        liquidityPool.perpetuals[perpetualIndex].donateInsuranceFund(totalAmount);
    }

    /**
     * @notice Deposit collateral to the trader's account of the perpetual. The trader's cash will increase.
     *         Activate the perpetual for the trader if the account in the perpetual is empty before depositing.
     *         Empty means cash and position are zero
     * @param liquidityPool The liquidity pool object
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
        int256 totalAmount =
            transferFromUserToPerpetual(liquidityPool, perpetualIndex, trader, amount);
        if (liquidityPool.perpetuals[perpetualIndex].deposit(trader, totalAmount)) {
            IPoolCreator(liquidityPool.creator).activatePerpetualFor(trader, perpetualIndex);
        }
    }

    /**
     * @notice Withdraw collateral from the trader's account of the perpetual. The trader's cash will decrease.
     *         Trader must be initial margin safe in the perpetual after withdrawing.
     *         Deactivate the perpetual for the trader if the account in the perpetual is empty after withdrawing.
     *         Empty means cash and position are zero
     * @param liquidityPool The liquidity pool object
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
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        rebalance(liquidityPool, perpetualIndex);
        if (perpetual.withdraw(trader, amount)) {
            IPoolCreator(liquidityPool.creator).deactivatePerpetualFor(trader, perpetualIndex);
        }
        transferFromPerpetualToUser(liquidityPool, perpetualIndex, payable(trader), amount);
    }

    /**
     * @notice If the state of the perpetual is "CLEARED", anyone authorized withdraw privilege by trader can settle
     *         trader's account in the perpetual. Which means to calculate how much the collateral should be returned
     *         to the trader, return it to trader's wallet and clear the trader's cash and position in the perpetual
     * @param liquidityPool The liquidity pool object
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
        transferFromPerpetualToUser(liquidityPool, perpetualIndex, payable(trader), marginToReturn);
    }

    /**
     * @notice Clear the next active account of the perpetual which state is "EMERGENCY" and send gas reward of collateral
     *         to sender. If all active accounts are cleared, the clear progress is done and the perpetual's state will
     *         change to "CLEARED". Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param liquidityPool The liquidity pool object
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     */
    function clear(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address trader
    ) public {
        PerpetualStorage storage perpetual = liquidityPool.perpetuals[perpetualIndex];
        if (
            perpetual.keeperGasReward > 0 && perpetual.totalCollateral >= perpetual.keeperGasReward
        ) {
            transferFromPerpetualToUser(
                liquidityPool,
                perpetualIndex,
                payable(trader),
                perpetual.keeperGasReward
            );
        }
        if (perpetual.clear(perpetual.getNextActiveAccount())) {
            setClearedState(liquidityPool, perpetualIndex);
        }
    }

    /**
     * @notice Add collateral to the liquidity pool and get the minted share tokens.
     *         The share token is the credential and use to get the collateral back when removing liquidity.
     * @param liquidityPool The liquidity pool object
     * @param trader The address of the trader that adding liquidity
     * @param cashToAdd The cash(collateral) to add
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
        // pool cash cannot be added before calculation, DO NOT use transferFromUserToPool
        increasePoolCash(liquidityPool, totalCashToAdd);
        shareToken.mint(trader, shareToMint.toUint256());
        emit AddLiquidity(trader, totalCashToAdd, shareToMint);
    }

    /**
     * @notice Remove collateral from the liquidity pool and redeem the share tokens when the liquidity pool is running
     * @param liquidityPool The liquidity pool object
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
        // pool cash cannot be added before calculation, DO NOT use transferFromPoolToUser
        decreasePoolCash(liquidityPool, cashToReturn);
        emit RemoveLiquidity(trader, cashToReturn, shareToRemove);
    }

    /**
     * @notice Increase the claimable fee(collateral) of the account
     * @param liquidityPool The liquidity pool object
     * @param account The address of the account
     * @param amount The amount of fee(collateral) to increase
     */
    function increaseFee(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        require(amount >= 0, "invalid fee amount");
        liquidityPool.claimableFees[account] = liquidityPool.claimableFees[account].add(amount);
        emit IncreaseFee(account, amount);
    }

    // /**
    //  * @notice Claimer claim his claimable fee(collateral) in the liquidity pool
    //  * @param liquidityPool The liquidity pool object
    //  * @param claimer The address of the claimer
    //  * @param amount The amount of fee(collateral) to claim, must less than claimable amount
    //  */
    // function claimFee(
    //     LiquidityPoolStorage storage liquidityPool,
    //     address claimer,
    //     int256 amount
    // ) public {
    //     require(amount > 0, "invalid amount");
    //     require(amount <= liquidityPool.claimableFees[claimer], "insufficient fee");
    //     liquidityPool.claimableFees[claimer] = liquidityPool.claimableFees[claimer].sub(amount);
    //     liquidityPool.transferToUser(payable(claimer), amount);
    //     emit ClaimFee(claimer, amount);
    // }

    /**
     * @notice To keep the AMM's margin equal to initial margin in the perpetual as posiible.
     *         Transfer collateral between the perpetual and the liquidity pool's cash, then
     *         update the AMM's cash in perpetual. The liquidity pool's cash can be negative,
     *         but the available cash can't. If AMM need to transfer and the available cash
     *         is not enough, transfer all the rest available cash of collateral
     * @param liquidityPool The liquidity pool object
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
            transferFromPerpetualToPool(liquidityPool, perpetualIndex, rebalanceMargin);
        } else {
            // from pool to perp
            int256 availablePoolCash = getAvailablePoolCash(liquidityPool, perpetualIndex);
            if (availablePoolCash < 0) {
                // pool has no more collateral, nothing to rebalance
                return;
            }
            rebalanceMargin = rebalanceMargin.abs().min(availablePoolCash);
            perpetual.updateCash(address(this), rebalanceMargin);
            transferFromPoolToPerpetual(liquidityPool, perpetualIndex, rebalanceMargin);
        }
    }

    /**
     * @notice Increase the liquidity pool's cash(collateral)
     * @param liquidityPool The liquidity pool object
     * @param amount The amount of cash(collateral) to increase
     */
    function increasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        require(amount >= 0, "increase negative pool cash");
        liquidityPool.poolCash = liquidityPool.poolCash.add(amount);
    }

    /**
     * @notice Decrease the liquidity pool's cash(collateral)
     * @param liquidityPool The liquidity pool object
     * @param amount The amount of cash(collateral) to decrease
     */
    function decreasePoolCash(LiquidityPoolStorage storage liquidityPool, int256 amount) internal {
        require(amount >= 0, "decrease negative pool cash");
        liquidityPool.poolCash = liquidityPool.poolCash.sub(amount);
    }

    // user <=> pool (addLiquidity/removeLiquidity)
    function transferFromUserToPool(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public returns (int256 totalAmount) {
        totalAmount = liquidityPool.transferFromUser(account, amount);
        increasePoolCash(liquidityPool, totalAmount);
    }

    function transferFromPoolToUser(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        liquidityPool.transferToUser(payable(account), amount);
        decreasePoolCash(liquidityPool, amount);
    }

    // user <=> perpetual (deposit/withdraw)
    function transferFromUserToPerpetual(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address account,
        int256 amount
    ) public returns (int256 totalAmount) {
        totalAmount = liquidityPool.transferFromUser(account, amount);
        liquidityPool.perpetuals[perpetualIndex].increaseTotalCollateral(totalAmount);
    }

    function transferFromPerpetualToUser(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        address account,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        liquidityPool.transferToUser(payable(account), amount);
        liquidityPool.perpetuals[perpetualIndex].decreaseTotalCollateral(amount);
    }

    // pool <=> perpetual (fee/rebalance)
    function transferFromPerpetualToPool(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        liquidityPool.perpetuals[perpetualIndex].decreaseTotalCollateral(amount);
        increasePoolCash(liquidityPool, amount);
    }

    function transferFromPoolToPerpetual(
        LiquidityPoolStorage storage liquidityPool,
        uint256 perpetualIndex,
        int256 amount
    ) public {
        if (amount == 0) {
            return;
        }
        liquidityPool.perpetuals[perpetualIndex].increaseTotalCollateral(amount);
        decreasePoolCash(liquidityPool, amount);
    }

    /**
     * @notice Check if the trader is authorized the privilege by the grantor. Any trader is authorized by himself
     * @param liquidityPool The liquidity pool object
     * @param trader The address of the trader
     * @param grantor The address of the grantor
     * @param privilege The privilege
     * @return isGranted True if the trader is authorized
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
