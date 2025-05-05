// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/**
 * @title LendyPositionManagerSlim
 * @author eliashezron
 * @notice Streamlined contract for managing lending and borrowing positions directly with Aave
 * @dev This contract combines supply and borrow functionality while staying under size limits
 */
contract LendyPositionManagerSingleton is Ownable {
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

    struct SupplyPosition {
        address owner;
        address asset;
        uint256 amount;
        bool active;
    }

    // ============ State Variables ============

    // The Aave Pool contract for lending and borrowing
    IPool public immutable POOL;

    // Position ID counter
    uint256 private _nextPositionId;

    // Supply Position ID counter
    uint256 private _nextSupplyPositionId;

    // Total number of active positions
    uint256 public totalActivePositions;

    // Total number of active supply positions
    uint256 public totalActiveSupplyPositions;

    // Mapping to track total borrowed amount by asset
    mapping(address => uint256) public totalBorrowedByAsset;

    // Mapping to track total supplied amount by asset
    mapping(address => uint256) public totalSuppliedByAsset;

    // Mapping of position ID to Position struct
    mapping(uint256 => Position) public positions;

    // Mapping of supply position ID to SupplyPosition struct
    mapping(uint256 => SupplyPosition) public supplyPositions;

    // Mapping of user address to positions IDs owned by that user
    mapping(address => uint256[]) private _userPositions;

    // Mapping of user address to supply positions IDs owned by that user
    mapping(address => uint256[]) private _userSupplyPositions;

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

    event SupplyPositionCreated(
        uint256 indexed supplyPositionId,
        address indexed owner,
        address asset,
        uint256 amount
    );

    event SupplyPositionClosed(uint256 indexed supplyPositionId, address indexed owner);
    event SupplyIncreased(uint256 indexed supplyPositionId, uint256 amount);
    event SupplyWithdrawn(uint256 indexed supplyPositionId, uint256 amount);

    // ============ Constructor ============

    /**
     * @param poolAddress The address of the Aave Pool contract
     */
    constructor(address poolAddress) Ownable(msg.sender) {
        POOL = IPool(poolAddress);
        _nextPositionId = 1;
        _nextSupplyPositionId = 1;
        totalActivePositions = 0;
        totalActiveSupplyPositions = 0;
    }

    // ============ Supply Functions ============

    /**
     * @notice Creates a supply position in Aave
     * @param asset The address of the asset to supply
     * @param amount The amount to supply
     * @return supplyPositionId The ID of the created supply position
     */
    function supply(
        address asset,
        uint256 amount
    ) external returns (uint256) {
        require(amount > 0, "Supply amount must be greater than 0");

        // Create a new supply position
        uint256 supplyPositionId = _nextSupplyPositionId++;
        SupplyPosition storage supplyPosition = supplyPositions[supplyPositionId];
        supplyPosition.owner = msg.sender;
        supplyPosition.asset = asset;
        supplyPosition.amount = amount;
        supplyPosition.active = true;

        // Add supply position to user's supply positions
        _userSupplyPositions[msg.sender].push(supplyPositionId);
        
        // Increment total active supply positions counter
        totalActiveSupplyPositions++;

        // Transfer asset from user and supply to Aave
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        SafeERC20.forceApprove(IERC20(asset), address(POOL), amount);
        
        // Supply to Aave Pool
        POOL.supply(asset, amount, address(this), 0);

        // Update total supplied amount for this asset
        totalSuppliedByAsset[asset] += amount;

        emit SupplyPositionCreated(
            supplyPositionId,
            msg.sender,
            asset,
            amount
        );

        return supplyPositionId;
    }

    /**
     * @notice Increases the supply amount for an existing supply position
     * @param supplyPositionId The ID of the supply position
     * @param additionalAmount The additional amount to supply
     */
    function increaseSupply(uint256 supplyPositionId, uint256 additionalAmount) external {
        SupplyPosition storage supplyPosition = supplyPositions[supplyPositionId];
        require(supplyPosition.active, "Supply position is not active");
        require(supplyPosition.owner == msg.sender, "Not supply position owner");
        require(additionalAmount > 0, "Amount must be greater than 0");

        // Transfer additional supply from user
        IERC20(supplyPosition.asset).safeTransferFrom(msg.sender, address(this), additionalAmount);
        
        // Supply additional amount to Aave
        SafeERC20.forceApprove(IERC20(supplyPosition.asset), address(POOL), additionalAmount);
        POOL.supply(supplyPosition.asset, additionalAmount, address(this), 0);

        // Update supply position amount
        supplyPosition.amount += additionalAmount;

        // Update total supplied amount for this asset
        totalSuppliedByAsset[supplyPosition.asset] += additionalAmount;

        emit SupplyIncreased(supplyPositionId, additionalAmount);
    }

    /**
     * @notice Withdraws supply from an existing supply position
     * @param supplyPositionId The ID of the supply position
     * @param withdrawAmount The amount to withdraw
     * @return The actual amount withdrawn
     */
    function withdrawSupply(uint256 supplyPositionId, uint256 withdrawAmount) external returns (uint256) {
        SupplyPosition storage supplyPosition = supplyPositions[supplyPositionId];
        require(supplyPosition.active, "Supply position is not active");
        require(supplyPosition.owner == msg.sender, "Not supply position owner");
        require(withdrawAmount > 0, "Amount must be greater than 0");
        require(withdrawAmount <= supplyPosition.amount, "Withdraw amount exceeds supply");
        
        // Withdraw supply from Aave
        uint256 withdrawnAmount = POOL.withdraw(supplyPosition.asset, withdrawAmount, msg.sender);
        
        // Update supply position amount
        supplyPosition.amount -= withdrawnAmount;
        
        // Update total supplied amount for this asset
        if (withdrawnAmount <= totalSuppliedByAsset[supplyPosition.asset]) {
            totalSuppliedByAsset[supplyPosition.asset] -= withdrawnAmount;
        } else {
            totalSuppliedByAsset[supplyPosition.asset] = 0;
        }
        
        // If all supply is withdrawn, mark the position as inactive
        if (supplyPosition.amount == 0) {
            supplyPosition.active = false;
            
            // Decrement total active supply positions counter
            if (totalActiveSupplyPositions > 0) {
                totalActiveSupplyPositions--;
            }
        }
        
        emit SupplyWithdrawn(supplyPositionId, withdrawnAmount);
        
        return withdrawnAmount;
    }

    /**
     * @notice Closes a supply position by withdrawing all supply
     * @param supplyPositionId The ID of the supply position
     */
    function closeSupplyPosition(uint256 supplyPositionId) external {
        SupplyPosition storage supplyPosition = supplyPositions[supplyPositionId];
        require(supplyPosition.active, "Supply position is not active");
        require(supplyPosition.owner == msg.sender, "Not supply position owner");

        // Store the supply amount before withdrawing
        uint256 supplyToWithdraw = supplyPosition.amount;

        // Withdraw all supply
        if (supplyToWithdraw > 0) {
            uint256 withdrawnAmount = POOL.withdraw(
                supplyPosition.asset,
                supplyToWithdraw,
                msg.sender
            );
            
            // Update total supplied amount for this asset
            if (withdrawnAmount <= totalSuppliedByAsset[supplyPosition.asset]) {
                totalSuppliedByAsset[supplyPosition.asset] -= withdrawnAmount;
            } else {
                totalSuppliedByAsset[supplyPosition.asset] = 0;
            }
        }

        // Mark supply position as inactive
        supplyPosition.active = false;
        supplyPosition.amount = 0;
        
        // Decrement total active supply positions counter
        if (totalActiveSupplyPositions > 0) {
            totalActiveSupplyPositions--;
        }

        emit SupplyPositionClosed(supplyPositionId, msg.sender);
    }

    // ============ Borrow Functions ============

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

    // ============ View Functions ============

    /**
     * @notice Get all positions owned by a user
     * @param user The user address
     * @return Array of position IDs
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }

    /**
     * @notice Get all supply positions owned by a user
     * @param user The user address
     * @return Array of supply position IDs
     */
    function getUserSupplyPositions(address user) external view returns (uint256[] memory) {
        return _userSupplyPositions[user];
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
     * @notice Get detailed supply position data
     * @param supplyPositionId The ID of the supply position
     * @return SupplyPosition data
     */
    function getSupplyPositionDetails(uint256 supplyPositionId) external view returns (SupplyPosition memory) {
        return supplyPositions[supplyPositionId];
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
     * @notice Get the Aave aToken address for the given asset
     * @param asset The address of the underlying asset
     * @return The address of the corresponding aToken
     */
    function getReserveAToken(address asset) external view returns (address) {
        DataTypes.ReserveData memory reserveData = POOL.getReserveData(asset);
        return reserveData.aTokenAddress;
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
     * @notice Get total amount supplied for a specific asset
     * @param asset The address of the asset
     * @return The total amount supplied for the asset
     */
    function getTotalSuppliedByAsset(address asset) external view returns (uint256) {
        return totalSuppliedByAsset[asset];
    }
} 