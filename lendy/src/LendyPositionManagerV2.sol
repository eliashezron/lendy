// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import {LendySupplyManager} from "./LendySupplyManager.sol";

/**
 * @title LendyPositionManager
 * @author eliashezron
 * @notice Contract for managing user lending and borrowing positions directly with Aave Pool
 * @dev This contract allows users to create positions with specific collateral and borrow parameters
 */
contract LendyPositionManagerV2 is LendySupplyManager {
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

    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed owner,
        address indexed liquidator,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount
    );

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
     * @notice Liquidates an unhealthy position
     * @param positionId The ID of the position to liquidate
     * @param debtToCover The amount of debt to cover
     * @param receiveAToken Whether to receive aTokens instead of the underlying collateral
     * @return liquidatedCollateralAmount The amount of collateral liquidated
     * @return debtAmount The amount of debt covered
     */
    function liquidatePosition(
        uint256 positionId,
        uint256 debtToCover,
        bool receiveAToken
    ) external returns (uint256 liquidatedCollateralAmount, uint256 debtAmount) {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        require(msg.sender != position.owner, "Owner cannot liquidate own position");
        
        // Get the current health factor of the position
        (,,,,, uint256 healthFactor) = POOL.getUserAccountData(address(this));
        
        // Ensure the position is unhealthy (health factor < 1.0)
        require(healthFactor < 1e18, "Position is healthy");
        
        // Transfer debt tokens from liquidator to this contract
        IERC20(position.borrowAsset).safeTransferFrom(msg.sender, address(this), debtToCover);
        
        // Approve liquidation
        SafeERC20.forceApprove(IERC20(position.borrowAsset), address(POOL), debtToCover);
        
        // Execute liquidation
        POOL.liquidationCall(
            position.collateralAsset,
            position.borrowAsset,
            address(this),
            debtToCover,
            receiveAToken
        );
        
        // For liquidation via Aave, we need to estimate the liquidated amounts
        // This is a simplified approach - in production you should get these values from events
        liquidatedCollateralAmount = (debtToCover * 105) / 100; // Assuming 5% liquidation bonus
        debtAmount = debtToCover;
        
        // Update total borrowed amount tracking
        if (debtAmount <= totalBorrowedByAsset[position.borrowAsset]) {
            totalBorrowedByAsset[position.borrowAsset] -= debtAmount;
        } else {
            totalBorrowedByAsset[position.borrowAsset] = 0;
        }
        
        // Update position data after liquidation, ensuring no underflows
        position.borrowAmount = position.borrowAmount > debtAmount ? position.borrowAmount - debtAmount : 0;
        position.collateralAmount = position.collateralAmount > liquidatedCollateralAmount ? 
                                    position.collateralAmount - liquidatedCollateralAmount : 0;
        
        // If the position was fully liquidated, mark it as inactive
        if (position.borrowAmount == 0 || position.collateralAmount == 0) {
            position.active = false;
            
            // Decrement total active positions counter if position is now inactive
            if (totalActivePositions > 0) {
                totalActivePositions--;
            }
        }
        
        // If liquidator chose to receive aTokens, they will be automatically transferred by Aave
        
        emit PositionLiquidated(
            positionId,
            position.owner,
            msg.sender,
            position.collateralAsset,
            position.borrowAsset,
            debtAmount,
            liquidatedCollateralAmount
        );
        
        return (liquidatedCollateralAmount, debtAmount);
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
     * @dev This is a more efficient way to get only active positions compared to filtering all positions
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
     * @dev This function allows getting all position details in a single call
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
     * @notice Admin function to close a position on behalf of a user
     * @param positionId The ID of the position to close
     * @param emergencyClose If true, admin can force close a position even if it's unhealthy
     * @dev This function will try to repay all debt using contract funds and withdraw collateral to the user
     * @dev It's designed for positions that have no debt or for emergency situations
     */
    function adminClosePosition(uint256 positionId, bool emergencyClose) external onlyOwner {
        Position storage position = positions[positionId];
        require(position.active, "Position is not active");
        
        address positionOwner = position.owner;
        
        // Check health factor unless emergency close is enabled
        if (!emergencyClose) {
            (,,,,, uint256 healthFactorBefore) = POOL.getUserAccountData(address(this));
            require(healthFactorBefore > 1e18, "Unhealthy position - use emergencyClose flag to force close");
        }
        
        // Get current debt
        uint256 currentDebt = position.borrowAmount;
        
        // Handle debt repayment if needed
        if (currentDebt > 0) {
            // Check if contract has enough of the borrow asset to repay
            uint256 contractBalance = IERC20(position.borrowAsset).balanceOf(address(this));
            
            if (contractBalance >= currentDebt) {
                // Contract has enough balance to repay
                SafeERC20.forceApprove(IERC20(position.borrowAsset), address(POOL), currentDebt);
                POOL.repay(
                    position.borrowAsset,
                    type(uint256).max, // repay all
                    position.interestRateMode,
                    address(this)
                );
                
                // Update total borrowed amount
                if (currentDebt <= totalBorrowedByAsset[position.borrowAsset]) {
                    totalBorrowedByAsset[position.borrowAsset] -= currentDebt;
                } else {
                    totalBorrowedByAsset[position.borrowAsset] = 0;
                }
            } else {
                // Not enough balance - require emergency flag
                require(emergencyClose, "Insufficient contract balance to repay debt - use emergencyClose for partial operations");
                
                if (contractBalance > 0) {
                    // Repay what we can
                    SafeERC20.forceApprove(IERC20(position.borrowAsset), address(POOL), contractBalance);
                    POOL.repay(
                        position.borrowAsset,
                        contractBalance,
                        position.interestRateMode,
                        address(this)
                    );
                    
                    // Update total borrowed amount for partial repayment
                    if (contractBalance <= totalBorrowedByAsset[position.borrowAsset]) {
                        totalBorrowedByAsset[position.borrowAsset] -= contractBalance;
                    } else {
                        totalBorrowedByAsset[position.borrowAsset] = 0;
                    }
                }
            }
        }
        
        // Withdraw collateral to the user
        if (position.collateralAmount > 0) {
            // This will withdraw all available collateral to the user
            try POOL.withdraw(
                position.collateralAsset,
                type(uint256).max, // withdraw all
                positionOwner // send directly to the position owner
            ) {} catch {
                if (emergencyClose) {
                    // Continue with the function in emergency mode, even if withdraw fails
                } else {
                    revert("Failed to withdraw collateral");
                }
            }
        }
        
        // Check the updated debt and collateral in Aave
        (,,,,, uint256 healthFactor) = POOL.getUserAccountData(address(this));
        
        // Mark position as inactive if it's safe or in emergency mode
        if (healthFactor > 1e18 || position.borrowAmount == 0 || emergencyClose) {
            position.active = false;
            position.borrowAmount = 0;
            position.collateralAmount = 0;
            
            // Decrement total active positions counter
            if (totalActivePositions > 0) {
                totalActivePositions--;
            }
            
            emit PositionClosed(positionId, positionOwner);
        } else {
            // If the position is still active but has been modified
            emit CollateralWithdrawn(positionId, position.collateralAmount);
            if (currentDebt > position.borrowAmount) {
                emit DebtRepaid(positionId, currentDebt - position.borrowAmount);
            }
        }
    }
    
    /**
     * @notice Get health factor for the contract
     * @return The health factor as reported by Aave
     * @dev This is useful to check the overall health of all positions
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