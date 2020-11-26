// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interface/IShareToken.sol";

import "../Type.sol";
import "../libraries/Constant.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../module/MarginModule.sol";
import "../module/OracleModule.sol";

import "./AMMCommon.sol";

import "hardhat/console.sol";

library AMMTradeModule {
	using Math for int256;
	using Math for uint256;
	using SafeMathExt for int256;
	using SignedSafeMath for int256;
	using SafeMath for uint256;
	using MarginModule for Core;
	using OracleModule for Core;

	int256 constant FUNDING_INTERVAL = 3600 * 8;

	function tradeWithAMM(
		Core storage core,
		int256 tradingAmount,
		bool partialFill
	) public view returns (int256 deltaMargin, int256 deltaPosition) {
		require(tradingAmount != 0, "Zero trade amount");
		int256 mc = core.cashBalance(address(this));
		int256 positionAmount = core.marginAccounts[address(this)].positionAmount;
		(int256 closingAmount, int256 openingAmount) = Utils.splitAmount(
			positionAmount,
			tradingAmount
		);
		deltaMargin = closePosition(core, mc, positionAmount, closingAmount);
		(int256 openDeltaMargin, int256 openDeltaPosition) = openPosition(
			core,
			mc.add(deltaMargin),
			positionAmount.add(closingAmount),
			openingAmount,
			partialFill
		);
		deltaMargin = deltaMargin.add(openDeltaMargin);
		deltaPosition = closingAmount.add(openDeltaPosition);
		int256 spread = core.halfSpreadRate.value.wmul(deltaMargin);
		deltaMargin = deltaMargin > 0 ? deltaMargin.add(spread) : deltaMargin.sub(spread);
	}

	function openPosition(
		Core storage core,
		int256 mc,
		int256 positionAmount,
		int256 tradingAmount,
		bool partialFill
	) internal view returns (int256 deltaMargin, int256 deltaPosition) {
		if (tradingAmount == 0) {
			return (0, 0);
		}
		int256 targetLeverage = core.targetLeverage.value;
		int256 openBeta = core.beta1.value;
		int256 indexPrice = core.indexPrice();
		if (!AMMCommon.isAMMMarginSafe(mc, positionAmount, indexPrice, targetLeverage, openBeta)) {
			if (partialFill) {
				return (0, 0);
			} else {
				revert("Unsafe before open position");
			}
		}

		int256 m0;
		int256 ma1;
		{
			int256 mv;
			(mv, m0) = AMMCommon.regress(mc, positionAmount, indexPrice, targetLeverage, openBeta);
			ma1 = mc.add(mv);
		}

		int256 newPosition = positionAmount.add(tradingAmount);
		int256 maxPosition;
		if (newPosition > 0) {
			maxPosition = _maxLongPosition(m0, indexPrice, openBeta, targetLeverage);
		} else {
			maxPosition = _maxShortPosition(m0, indexPrice, openBeta, targetLeverage);
		}
		if (
			(newPosition > maxPosition && newPosition > 0) ||
			(newPosition < maxPosition && newPosition < 0)
		) {
			if (partialFill) {
				deltaPosition = maxPosition.sub(positionAmount);
				newPosition = maxPosition;
			} else {
				revert("Trade amount exceeds max amount");
			}
		} else {
			deltaPosition = tradingAmount;
		}
		if (newPosition > 0) {
			deltaMargin = longDeltaMargin(
				m0,
				ma1,
				positionAmount,
				newPosition,
				indexPrice,
				openBeta
			);
		} else {
			deltaMargin = shortDeltaMargin(m0, positionAmount, newPosition, indexPrice, openBeta);
		}
	}

	function closePosition(
		Core storage core,
		int256 mc,
		int256 positionAmount,
		int256 tradingAmount
	) internal view returns (int256 deltaMargin) {
		if (tradingAmount == 0) {
			return 0;
		}
		require(positionAmount != 0, "Zero position amount before close position");
		int256 targetLeverage = core.targetLeverage.value;
		int256 closingBeta = core.beta2.value;
		int256 indexPrice = core.indexPrice();
		if (
			AMMCommon.isAMMMarginSafe(mc, positionAmount, indexPrice, targetLeverage, closingBeta)
		) {
			(int256 mv, int256 m0) = AMMCommon.regress(
				mc,
				positionAmount,
				indexPrice,
				targetLeverage,
				closingBeta
			);
			int256 newPositionAmount = positionAmount.add(tradingAmount);
			if (newPositionAmount == 0) {
				return m0.wdiv(targetLeverage).sub(mc);
			} else {
				if (positionAmount > 0) {
					deltaMargin = longDeltaMargin(
						m0,
						mc.add(mv),
						positionAmount,
						newPositionAmount,
						indexPrice,
						closingBeta
					);
				} else {
					deltaMargin = shortDeltaMargin(
						m0,
						positionAmount,
						newPositionAmount,
						indexPrice,
						closingBeta
					);
				}
			}
		} else {
			deltaMargin = indexPrice.wmul(tradingAmount).neg();
		}
	}

	function longDeltaMargin(
		int256 m0,
		int256 ma,
		int256 positionAmount1,
		int256 positionAmount2,
		int256 indexPrice,
		int256 beta
	) internal pure returns (int256 deltaMargin) {
		int256 a = Constant.SIGNED_ONE.sub(beta).wmul(ma).mul(2);
		int256 b = positionAmount2.sub(positionAmount1).wmul(indexPrice);
		b = a.div(2).sub(b).wmul(ma);
		b = b.sub(beta.wmul(m0).wmul(m0));
		int256 beforeSqrt = beta.wmul(a).wmul(ma).wmul(m0).mul(m0).mul(2);
		beforeSqrt = beforeSqrt.add(b.mul(b));
		deltaMargin = beforeSqrt.sqrt().add(b).wdiv(a).sub(ma);
	}

	function shortDeltaMargin(
		int256 m0,
		int256 positionAmount1,
		int256 positionAmount2,
		int256 indexPrice,
		int256 beta
	) internal pure returns (int256 deltaMargin) {
		deltaMargin = beta.wmul(m0).wmul(m0);
		deltaMargin = deltaMargin.wdiv(positionAmount1.wmul(indexPrice).add(m0));
		deltaMargin = deltaMargin.wdiv(positionAmount2.wmul(indexPrice).add(m0));
		deltaMargin = deltaMargin.add(Constant.SIGNED_ONE).sub(beta);
		deltaMargin = deltaMargin.wmul(indexPrice).wmul(positionAmount2.sub(positionAmount1)).neg();
	}

	function _maxLongPosition(
		int256 m0,
		int256 indexPrice,
		int256 beta,
		int256 targetLeverage
	) internal pure returns (int256 maxLongPosition) {
		if (beta.wmul(targetLeverage) == Constant.SIGNED_ONE.sub(beta)) {
			maxLongPosition = beta.mul(2).neg().add(Constant.SIGNED_ONE).mul(2).wmul(indexPrice);
			maxLongPosition = m0.wdiv(maxLongPosition);
		} else {
			int256 tmp1 = targetLeverage.sub(Constant.SIGNED_ONE);
			int256 tmp2 = tmp1.add(beta);
			int256 tmp3 = beta.mul(2).sub(Constant.SIGNED_ONE);
			maxLongPosition = beta.mul(tmp2).sqrt();
			maxLongPosition = beta.add(tmp2).sub(Constant.SIGNED_ONE).wmul(maxLongPosition);
			maxLongPosition = tmp2.wmul(tmp3).add(maxLongPosition).wdiv(tmp1).wdiv(
				beta.wmul(tmp1).add(tmp3)
			);
			maxLongPosition = maxLongPosition.wfrac(m0, indexPrice);
		}
	}

	function _maxShortPosition(
		int256 m0,
		int256 indexPrice,
		int256 beta,
		int256 targetLeverage
	) internal pure returns (int256 maxShortPosition) {
		maxShortPosition = beta.mul(targetLeverage).sqrt().add(Constant.SIGNED_ONE).wmul(
			indexPrice
		);
		maxShortPosition = m0.wdiv(maxShortPosition).neg();
	}

	function addLiquidity(
		Core storage core,
		int256 shareTotalSupply,
		int256 marginToAdd
	) public view returns (int256 share) {
		require(marginToAdd > 0, "Must add positive liquidity");
		int256 mc = core.cashBalance(address(this));
		int256 positionAmount = core.marginAccounts[address(this)].positionAmount;
		int256 targetLeverage = core.targetLeverage.value;
		int256 beta = core.beta1.value;
		int256 indexPrice = core.indexPrice();
		int256 m0;
		int256 newM0;
		if (AMMCommon.isAMMMarginSafe(mc, positionAmount, indexPrice, targetLeverage, beta)) {
			(, m0) = AMMCommon.regress(mc, positionAmount, indexPrice, targetLeverage, beta);
		} else {
			m0 = indexPrice.wmul(positionAmount).add(mc);
		}
		mc = mc.add(marginToAdd);
		if (AMMCommon.isAMMMarginSafe(mc, positionAmount, indexPrice, targetLeverage, beta)) {
			(, newM0) = AMMCommon.regress(mc, positionAmount, indexPrice, targetLeverage, beta);
		} else {
			newM0 = indexPrice.wmul(positionAmount).add(mc);
		}
		if (m0 == 0) {
			if (shareTotalSupply == 0) {
				share = newM0;
			} else {
				revert("share has no value");
			}
		} else {
			share = newM0.sub(m0).wdiv(m0).wmul(shareTotalSupply);
		}
	}

	function removeLiquidity(
		Core storage core,
		int256 shareTotalSupply,
		int256 shareToRemove
	) public view returns (int256 marginToRemove) {
		int256 mc = core.cashBalance(address(this));
		int256 positionAmount = core.marginAccounts[address(this)].positionAmount;
		int256 targetLeverage = core.targetLeverage.value;
		int256 beta = core.beta1.value;
		int256 indexPrice = core.indexPrice();
		require(
			AMMCommon.isAMMMarginSafe(mc, positionAmount, indexPrice, targetLeverage, beta),
			"Unsafe before remove liquidity"
		);
		int256 shareRatio = shareTotalSupply.sub(shareToRemove).wdiv(shareTotalSupply);
		(, int256 m0) = AMMCommon.regress(mc, positionAmount, indexPrice, targetLeverage, beta);
		m0 = m0.wmul(shareRatio);
		if (positionAmount > 0) {
			require(
				positionAmount <= _maxLongPosition(m0, indexPrice, beta, targetLeverage),
				"Unsafe after remove liquidity"
			);
		} else if (positionAmount < 0) {
			require(
				positionAmount >= _maxShortPosition(m0, indexPrice, beta, targetLeverage),
				"Unsafe after remove liquidity"
			);
		}
		marginToRemove = _marginToRemove(indexPrice, mc, m0, positionAmount, targetLeverage, beta);
	}

	function _marginToRemove(
		int256 indexPrice,
		int256 mc,
		int256 m0,
		int256 positionAmount,
		int256 targetLeverage,
		int256 beta
	) internal pure returns (int256 marginToRemove) {
		int256 positionValue = indexPrice.wmul(positionAmount);
		if (positionAmount <= 0) {
			int256 newMc = positionValue
				.wmul(positionValue)
				.wmul(beta)
				.wdiv(positionValue.add(m0))
				.sub(positionValue)
				.add(m0.wdiv(targetLeverage));
			marginToRemove = mc.sub(newMc);
		} else {
			int256 beforeSqrt = m0.sub(positionValue).mul(m0.sub(positionValue));
			beforeSqrt = beta.wmul(m0).mul(positionValue).mul(4).add(beforeSqrt);
			int256 newMc = beforeSqrt
				.sqrt()
				.sub(positionValue)
				.sub(m0)
				.wdiv(Constant.SIGNED_ONE.sub(beta))
				.div(2)
				.add(m0.wdiv(targetLeverage));
			marginToRemove = mc.sub(newMc);
		}
	}
}
