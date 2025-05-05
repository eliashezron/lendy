// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import {LendySupplyManager} from "./LendySupplyManager.sol";

/**
 * @title LendyPositionManagerV2Split
 * @author eliashezron
 * @notice Split version of LendyPositionManager focusing only on borrowing functionality
 * @dev This contract is a trimmed-down version to fit within contract size limits
 */
contract LendyPositionManagerV2Split is LendySupplyManager {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct Position {
        address owner;
        address collateralAsset;
        uint256 collateralAmount;
        address borrowAsset;
        uint256 borrowAmount;
        uint256 interestRateMode; // 1 for stable, 2 for variable
        bool active;
    }

    // ============ State Variables ============

    // Position ID counter
    uint256 private _nextPositionId;

    // Total number of active positions
    uint256 public totalActivePositions;

    // Mapping to track total borrowed amount by asset
    mapping(address => uint256) public totalBorrowedByAsset;

    // Mapping of position ID to Position struct
    mapping(uint256 => Position) public positions;

    // Mapping of user address to positions IDs owned by that user
    mapping(address => uint256[]) private _userPositions;

    // ============ Events ============

    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        address collateralAsset,
        uint256 collateralAmount,
        address borrowAsset,
        uint256 borrowAmount,
        uint256 interestRateMode
    );

    event PositionClosed(uint256 indexed positionId, address indexed owner);

    event CollateralAdded(uint256 indexed positionId, uint256 amount);
    
    event CollateralWithdrawn(uint256 indexed positionId, uint256 amount);

    event DebtRepaid(uint256 indexed positionId, uint256 amount);
    
    event DebtIncreased(uint256 indexed positionId, uint256 amount);

    // ============ Constructor ============

    /**
     * @param poolAddress The address of the Aave Pool contract
     */
    constructor(address poolAddress) LendySupplyManager(poolAddress) {
        _nextPositionId = 1;
        totalActivePositions = 0;
    }

    // ============ External Functions ============

    /**
     * @notice Creates a new lending and borrowing position
     * @param collateralAsset The address of the collateral asset
     * @param collateralAmount The amount of collateral to supply
     * @param borrowAsset The address of the asset to borrow
     * @param borrowAmount The amount to borrow
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @return positionId The ID of the created position
     */
    function createPosition(
        address collateralAsset,
        uint256 collateralAmount,
        address borrowAsset,
        uint256 borrowAmount,
        uint256 interestRateMode
    ) external returns (uint256) {
        require(collateralAmount > 0, "Collateral amount must be greater than 0");
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");

        // Create a new position
        uint256 positionId = _nextPositionId++;
        Position storage position = positions[positionId];
        position.owner = msg.sender;
        position.collateralAsset = collateralAsset;
        position.collateralAmount = collateralAmount;
        position.borrowAsset = borrowAsset;
        position.borrowAmount = borrowAmount;
        position.interestRateMode = interestRateMode;
        position.active = true;

        // Add position to user's positions
        _userPositions[msg.sender].push(positionId);
        
        // Increment total active positions counter
        totalActivePositions++;

        // Transfer collateral from user and supply to Aave
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
        SafeERC20.forceApprove(IERC20(collateralAsset), address(POOL), collateralAmount);
        
        // Supply to Aave Pool
        POOL.supply(collateralAsset, collateralAmount, address(this), 0);

        // Set asset to be used as collateral
        POOL.setUserUseReserveAsCollateral(collateralAsset, true);

        // Try to borrow 
        try POOL.borrow(borrowAsset, borrowAmount, interestRateMode, 0, address(this)) {
            // Transfer borrowed funds to the user
            IERC20(borrowAsset).safeTransfer(msg.sender, borrowAmount);
            
            // Update total borrowed amount for this asset
            totalBorrowedByAsset[borrowAsset] += borrowAmount;
        } catch {
            // If borrowing fails with the full amount, try half the amount
            uint256 reducedAmount = borrowAmount / 2;
            if (reducedAmount > 0) {
                try POOL.borrow(borrowAsset, reducedAmount, interestRateMode, 0, address(this)) {
                    // Update the position with the actual borrowed amount
                    position.borrowAmount = reducedAmount;
                    // Transfer the reduced borrowed funds to the user
                    IERC20(borrowAsset).safeTransfer(msg.sender, reducedAmount);
                    
                    // Update total borrowed amount for this asset with the reduced amount
                    totalBorrowedByAsset[borrowAsset] += reducedAmount;
                } catch {
                    revert("All borrow attempts failed");
                }
            } else {
                revert("All borrow attempts failed");
            }
        }

        emit PositionCreated(
            positionId,
            msg.sender,
            collateralAsset,
            collateralAmount,
            borrowAsset,
            position.borrowAmount,
            interestRateMode
        );

        return positionId;
    }

    /**
     * @notice Adds collateral to an existing position
     * @param positionId The ID of the position
     * @param additionalAmount The additional amount of collateral to add
     */
    function addCollateral(uint256 positionId, uint256 additionalAmount) external {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(position.owner == msg.sender, "Not position owner");
        require(additionalAmount > 0, "Amount must be greater than 0");

        // Transfer additional collateral from user
        IERC20(position.collateralAsset).safeTransferFrom(msg.sender, address(this), additionalAmount);
        
        // Supply additional collateral to Aave
        SafeERC20.forceApprove(IERC20(position.collateralAsset), address(POOL), additionalAmount);
        POOL.supply(position.collateralAsset, additionalAmount, address(this), 0);

        // Make sure collateral is enabled
        POOL.setUserUseReserveAsCollateral(position.collateralAsset, true);
        
        // Update position collateral amount
        position.collateralAmount += additionalAmount;

        emit CollateralAdded(positionId, additionalAmount);
    }

    /**
     * @notice Withdraws collateral from an existing position
     * @param positionId The ID of the position
     * @param withdrawAmount The amount of collateral to withdraw
     * @return The actual amount withdrawn
     */
    function withdrawCollateral(uint256 positionId, uint256 withdrawAmount) external returns (uint256) {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(position.owner == msg.sender, "Not position owner");
        require(withdrawAmount > 0, "Amount must be greater than 0");
        require(withdrawAmount <= position.collateralAmount, "Withdraw amount exceeds collateral");
        
        // Check health factor before withdrawal
        (,,,,, uint256 healthFactor) = POOL.getUserAccountData(address(this));
        require(healthFactor > 1e18, "Unhealthy position");
        
        // Withdraw collateral from Aave
        uint256 withdrawnAmount = POOL.withdraw(position.collateralAsset, withdrawAmount, msg.sender);
        
        // Update position collateral amount
        position.collateralAmount -= withdrawnAmount;
        
        // Check health factor after withdrawal
        (,,,,, healthFactor) = POOL.getUserAccountData(address(this));
        require(healthFactor > 1e18, "Withdrawal would make position unhealthy");
        
        emit CollateralWithdrawn(positionId, withdrawnAmount);
        
        return withdrawnAmount;
    }

    /**
     * @notice Increases the borrowed amount for an existing position
     * @param positionId The ID of the position
     * @param additionalBorrowAmount The additional amount to borrow
     * @return The actual additional amount borrowed
     */
    function increaseBorrow(uint256 positionId, uint256 additionalBorrowAmount) external returns (uint256) {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(position.owner == msg.sender, "Not position owner");
        require(additionalBorrowAmount > 0, "Amount must be greater than 0");
        
        // Check health factor and borrowing capacity before borrowing
        (,,uint256 availableBorrowsBase,,,uint256 healthFactor) = POOL.getUserAccountData(address(this));
        require(availableBorrowsBase > 0, "No borrowing capacity");
        require(healthFactor > 1e18, "Position is already unhealthy");
        
        // Try to borrow
        uint256 borrowedAmount = additionalBorrowAmount;
        try POOL.borrow(position.borrowAsset, additionalBorrowAmount, position.interestRateMode, 0, address(this)) {
            // Transfer borrowed funds to the user
            IERC20(position.borrowAsset).safeTransfer(msg.sender, additionalBorrowAmount);
            
            // Update total borrowed amount for this asset
            totalBorrowedByAsset[position.borrowAsset] += additionalBorrowAmount;
        } catch {
            // If borrowing fails, try with reduced amount
            uint256 reducedAmount = additionalBorrowAmount / 2;
            if (reducedAmount > 0) {
                try POOL.borrow(position.borrowAsset, reducedAmount, position.interestRateMode, 0, address(this)) {
                    borrowedAmount = reducedAmount;
                    // Transfer reduced borrowed funds to the user
                    IERC20(position.borrowAsset).safeTransfer(msg.sender, reducedAmount);
                    
                    // Update total borrowed amount for this asset with the reduced amount
                    totalBorrowedByAsset[position.borrowAsset] += reducedAmount;
                } catch {
                    revert("All borrow attempts failed");
                }
            } else {
                revert("All borrow attempts failed");
            }
        }
        
        // Update position borrow amount
        position.borrowAmount += borrowedAmount;
        
        // Verify position health after borrowing
        (,,,,, healthFactor) = POOL.getUserAccountData(address(this));
        require(healthFactor > 1e18, "Borrow would make position unhealthy");
        
        emit DebtIncreased(positionId, borrowedAmount);
        
        return borrowedAmount;
    }

    /**
     * @notice Repays debt for an existing position
     * @param positionId The ID of the position
     * @param amount The amount of debt to repay
     */
    function repayDebt(uint256 positionId, uint256 amount) external {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(position.owner == msg.sender, "Not position owner");
        require(amount > 0, "Amount must be greater than 0");

        // Transfer repayment amount from user to this contract
        IERC20(position.borrowAsset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Repay debt to Aave
        SafeERC20.forceApprove(IERC20(position.borrowAsset), address(POOL), amount);
        uint256 repaidAmount = POOL.repay(
            position.borrowAsset,
            amount,
            position.interestRateMode,
            address(this)
        );

        // Decrease total borrowed amount tracker
        if (repaidAmount <= totalBorrowedByAsset[position.borrowAsset]) {
            totalBorrowedByAsset[position.borrowAsset] -= repaidAmount;
        } else {
            totalBorrowedByAsset[position.borrowAsset] = 0;
        }

        // Update position borrow amount
        if (repaidAmount >= position.borrowAmount) {
            position.borrowAmount = 0;
        } else {
            position.borrowAmount -= repaidAmount;
        }

        emit DebtRepaid(positionId, repaidAmount);
    }

    /**
     * @notice Closes a position by repaying all debt and withdrawing all collateral
     * @param positionId The ID of the position
     */
    function closePosition(uint256 positionId) external {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(position.owner == msg.sender, "Not position owner");

        // Get the current debt amount (simplified)
        uint256 currentDebt = position.borrowAmount;
        
        // Check the health factor
        (,,,,, uint256 healthFactor) = POOL.getUserAccountData(address(this));
        require(healthFactor > 1e18, "Unhealthy position");

        // If there's any remaining debt, user needs to transfer it for repayment
        if (currentDebt > 0) {
            IERC20(position.borrowAsset).safeTransferFrom(
                msg.sender,
                address(this),
                currentDebt
            );
            
            // Repay all debt
            SafeERC20.forceApprove(IERC20(position.borrowAsset), address(POOL), currentDebt);
            POOL.repay(
                position.borrowAsset,
                type(uint256).max, // repay all
                position.interestRateMode,
                address(this)
            );
            
            // Update total borrowed amount on closure
            if (currentDebt <= totalBorrowedByAsset[position.borrowAsset]) {
                totalBorrowedByAsset[position.borrowAsset] -= currentDebt;
            } else {
                totalBorrowedByAsset[position.borrowAsset] = 0;
            }
        }

        // Store the collateral amount before withdrawing
        uint256 collateralToWithdraw = position.collateralAmount;

        // Withdraw all collateral
        if (collateralToWithdraw > 0) {
            POOL.withdraw(
                position.collateralAsset,
                collateralToWithdraw,
                msg.sender
            );
        }

        // Mark position as inactive
        position.active = false;
        position.borrowAmount = 0;
        position.collateralAmount = 0;
        
        // Decrement total active positions counter
        if (totalActivePositions > 0) {
            totalActivePositions--;
        }

        emit PositionClosed(positionId, msg.sender);
    }

    /**
     * @notice Get all positions owned by a user
     * @param user The user address
     * @return Array of position IDs
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }

    /**
     * @notice Get detailed position data
     * @param positionId The ID of the position
     * @return Position data
     */
    function getPositionDetails(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    /**
     * @notice Get the Aave aToken address for the given asset
     * @param asset The address of the underlying asset
     * @return The address of the corresponding aToken
     */
    function getReserveAToken(address asset) external view returns (address) {
        DataTypes.ReserveData memory reserveData = POOL.getReserveData(asset);
        return reserveData.aTokenAddress;
    }

    /**
     * @notice Get all active positions owned by a user
     * @param user The user address
     * @return Array of active position IDs
     */
    function getUserActivePositions(address user) external view returns (uint256[] memory) {
        uint256[] memory allPositions = _userPositions[user];
        
        // First, count active positions
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allPositions.length; i++) {
            if (positions[allPositions[i]].active) {
                activeCount++;
            }
        }
        
        // Create result array with exact size needed
        uint256[] memory activePositions = new uint256[](activeCount);
        
        // Fill the result array
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < allPositions.length; i++) {
            if (positions[allPositions[i]].active) {
                activePositions[resultIndex] = allPositions[i];
                resultIndex++;
            }
        }
        
        return activePositions;
    }
    
    /**
     * @notice Get user positions with full details
     * @param user The user address
     * @return Array of Position structs with full details
     */
    function getUserPositionsWithDetails(address user) external view returns (Position[] memory) {
        uint256[] memory positionIds = _userPositions[user];
        Position[] memory userPositions = new Position[](positionIds.length);
        
        for (uint256 i = 0; i < positionIds.length; i++) {
            userPositions[i] = positions[positionIds[i]];
        }
        
        return userPositions;
    }
    
    /**
     * @notice Get health factor for the contract
     * @return The health factor as reported by Aave
     */
    function getHealthFactor() external view returns (uint256) {
        (,,,,, uint256 healthFactor) = POOL.getUserAccountData(address(this));
        return healthFactor;
    }

    /**
     * @notice Get total amount borrowed for a specific asset
     * @param asset The address of the asset
     * @return The total amount borrowed for the asset
     */
    function getTotalBorrowedByAsset(address asset) external view returns (uint256) {
        return totalBorrowedByAsset[asset];
    }
    
    /**
     * @notice Get the total number of active positions
     * @return The total count of active positions
     */
    function getTotalActivePositions() external view returns (uint256) {
        return totalActivePositions;
    }
    
    /**
     * @notice Get the total number of positions ever created
     * @return The total count of positions created (next position ID - 1)
     */
    function getTotalPositionsCreated() external view returns (uint256) {
        return _nextPositionId - 1;
    }
} 