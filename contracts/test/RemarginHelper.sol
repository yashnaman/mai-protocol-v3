// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPoolCreator {
    function grantPrivilege(address trader, uint256 privilege) external;

    function isGranted(
        address owner,
        address trader,
        uint256 privilege
    ) external view returns (bool);

    function getWeth() external view returns (address);
}

interface IPerpetual {
    function getLiquidityPoolInfo()
        external
        view
        returns (
            bool isRunning,
            bool isFastCreationEnabled,
            // [0] creator,
            // [1] operator,
            // [2] transferringOperator,
            // [3] governor,
            // [4] shareToken,
            // [5] collateralToken,
            // [6] vault,
            address[7] memory addresses,
            // [0] vaultFeeRate,
            // [1] poolCash,
            // [2] insuranceFundCap,
            // [3] insuranceFund,
            // [4] donatedInsuranceFund,
            int256[5] memory intNums,
            // [0] collateralDecimals,
            // [1] perpetualCount
            // [2] fundingTime,
            // [3] operatorExpiration,
            uint256[4] memory uintNums
        );

    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) external payable;

    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        bool needUnwrap
    ) external;
}

contract RemarginHelper is ReentrancyGuard {
    function remargin(
        address from,
        uint256 fromIndex,
        address to,
        uint256 toIndex,
        int256 amount
    ) external nonReentrant {
        require(amount > 0, "remargin amount is zero");
        address collateralFrom = _collateral(from);
        address collateralTo = _collateral(to);
        require(
            collateralFrom == collateralTo,
            "cannot remargin between perpetuals with different collaterals"
        );
        require(
            IERC20(collateralFrom).allowance(msg.sender, to) >= uint256(amount),
            "remargin amount exceeds allowance"
        );
        IPerpetual(from).withdraw(fromIndex, msg.sender, amount, false);
        IPerpetual(to).deposit(toIndex, msg.sender, amount);
    }

    function _collateral(address perpetual) internal view returns (address collateral) {
        (, , address[7] memory addresses, , ) = IPerpetual(perpetual).getLiquidityPoolInfo();
        collateral = addresses[5];
    }
}
