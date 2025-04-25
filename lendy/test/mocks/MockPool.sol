// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockPool
 * @notice Mock Aave Pool for testing
 */
contract MockPool {
    // Supply tracking
    address public lastSupplyAsset;
    uint256 public lastSupplyAmount;
    address public lastSupplyOnBehalfOf;
    uint16 public lastSupplyReferralCode;

    // Withdraw tracking
    address public lastWithdrawAsset;
    uint256 public lastWithdrawAmount;
    address public lastWithdrawTo;

    // Borrow tracking
    address public lastBorrowAsset;
    uint256 public lastBorrowAmount;
    uint256 public lastBorrowInterestRateMode;
    uint16 public lastBorrowReferralCode;
    address public lastBorrowOnBehalfOf;

    // Repay tracking
    address public lastRepayAsset;
    uint256 public lastRepayAmount;
    uint256 public lastRepayInterestRateMode;
    address public lastRepayOnBehalfOf;

    // Liquidation tracking
    address public lastLiquidationCollateralAsset;
    address public lastLiquidationDebtAsset;
    address public lastLiquidationUser;
    uint256 public lastLiquidationDebtToCover;
    bool public lastLiquidationReceiveAToken;

    // Collateral tracking
    address public lastSetUserUseReserveAsCollateralAsset;
    bool public lastSetUserUseReserveAsCollateralUseAsCollateral;

    // Mock health factor
    uint256 public mockHealthFactor = 2e18; // Default to 2.0

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        lastSupplyAsset = asset;
        lastSupplyAmount = amount;
        lastSupplyOnBehalfOf = onBehalfOf;
        lastSupplyReferralCode = referralCode;
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        lastWithdrawAsset = asset;
        lastWithdrawAmount = amount;
        lastWithdrawTo = to;
        
        // Simulate withdrawal by transferring tokens to the recipient
        // In a real scenario, the aTokens would be burned and the underlying asset transferred
        if (amount != type(uint256).max) {
            try IERC20(asset).transfer(to, amount) {
                // Transfer successful
            } catch {
                // If transfer fails, try minting if it's a MockERC20
                try MockERC20(asset).mint(to, amount) {
                    // Mint successful
                } catch {
                    // Both transfer and mint failed, but we'll continue for testing
                }
            }
        } else {
            // For type(uint256).max, we'll just mint a fixed amount
            try MockERC20(asset).mint(to, 1000 * 10**18) {
                // Mint successful
            } catch {
                // Mint failed, but we'll continue for testing
            }
        }
        
        // Return the same amount as requested for simplicity
        return amount;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {
        lastBorrowAsset = asset;
        lastBorrowAmount = amount;
        lastBorrowInterestRateMode = interestRateMode;
        lastBorrowReferralCode = referralCode;
        lastBorrowOnBehalfOf = onBehalfOf;
        
        // Simulate borrowing by directly minting tokens to the msg.sender
        // Skip trying to transfer first since it will likely fail in tests
        try MockERC20(asset).mint(msg.sender, amount) {
            // Mint successful
        } catch {
            // Mint failed, but we'll continue for testing
        }
    }

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256) {
        lastRepayAsset = asset;
        lastRepayAmount = amount;
        lastRepayInterestRateMode = interestRateMode;
        lastRepayOnBehalfOf = onBehalfOf;
        
        // Return the same amount as requested for simplicity
        return amount;
    }

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external {
        lastLiquidationCollateralAsset = collateralAsset;
        lastLiquidationDebtAsset = debtAsset;
        lastLiquidationUser = user;
        lastLiquidationDebtToCover = debtToCover;
        lastLiquidationReceiveAToken = receiveAToken;
        
        // Calculate liquidation amount (in a real scenario this would depend on the liquidation bonus)
        uint256 liquidationBonus = 1.05e18; // 5% bonus
        uint256 liquidatedCollateralAmount = (debtToCover * liquidationBonus) / 1e18;
        
        // Simulate transferring the liquidated collateral to the liquidator
        try MockERC20(collateralAsset).mint(msg.sender, liquidatedCollateralAmount) {
            // Mint successful
        } catch {
            // Mint failed, but we'll continue for testing
        }
    }

    function setUserUseReserveAsCollateral(
        address asset,
        bool useAsCollateral
    ) external {
        lastSetUserUseReserveAsCollateralAsset = asset;
        lastSetUserUseReserveAsCollateralUseAsCollateral = useAsCollateral;
    }

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return (
            1000e18, // totalCollateralBase: 1000 ETH equivalent
            500e18,  // totalDebtBase: 500 ETH equivalent
            500e18,  // availableBorrowsBase: 500 ETH equivalent
            8500,    // currentLiquidationThreshold: 85%
            8000,    // ltv: 80%
            mockHealthFactor // healthFactor
        );
    }

    // Helper to set mock health factor for testing
    function setMockHealthFactor(uint256 healthFactor) external {
        mockHealthFactor = healthFactor;
    }
    
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external {
        // Just forward to the regular supply method for our mock
        lastSupplyAsset = asset;
        lastSupplyAmount = amount;
        lastSupplyOnBehalfOf = onBehalfOf;
        lastSupplyReferralCode = referralCode;
    }
    
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (uint256) {
        // Just forward to the regular repay tracking for our mock
        lastRepayAsset = asset;
        lastRepayAmount = amount;
        lastRepayInterestRateMode = interestRateMode;
        lastRepayOnBehalfOf = onBehalfOf;
        
        // Return the same amount as requested for simplicity
        return amount;
    }
    
    function getReserveAToken(address asset) external view returns (address) {
        // This is a mock implementation that returns the asset address itself
        // In a real scenario, this would return the associated aToken address
        return asset;
    }
} 