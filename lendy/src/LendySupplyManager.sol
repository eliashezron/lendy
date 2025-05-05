// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";

/**
 * @title LendySupplyManager
 * @author eliashezron
 * @notice Base contract for managing user supply positions directly with Aave Pool
 * @dev This contract handles only supply operations to reduce contract size
 */
abstract contract LendySupplyManager is Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============

    struct SupplyPosition {
        address owner;
        address asset;
        uint256 amount;
        bool active;
        uint256 interestRateMode; // 1 for stable, 2 for variable (for future use)
    }

    // ============ State Variables ============

    // The Aave Pool contract for lending and borrowing
    IPool public immutable POOL;

    // Supply Position ID counter
    uint256 internal _nextSupplyPositionId;

    // Total number of active supply positions
    uint256 public totalActiveSupplyPositions;

    // Mapping to track total supplied amount by asset
    mapping(address => uint256) public totalSuppliedByAsset;

    // Mapping of supply position ID to SupplyPosition struct
    mapping(uint256 => SupplyPosition) public supplyPositions;

    // Mapping of user address to supply positions IDs owned by that user
    mapping(address => uint256[]) internal _userSupplyPositions;

    // ============ Events ============

    event SupplyPositionCreated(
        uint256 indexed supplyPositionId,
        address indexed owner,
        address asset,
        uint256 amount,
        uint256 interestRateMode
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
        _nextSupplyPositionId = 1;
        totalActiveSupplyPositions = 0;
    }

    // ============ External Functions ============

    /**
     * @notice Creates a supply position in Aave
     * @param asset The address of the asset to supply
     * @param amount The amount to supply
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @return supplyPositionId The ID of the created supply position
     */
    function supply(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256) {
        require(amount > 0, "Supply amount must be greater than 0");
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");

        // Create a new supply position
        uint256 supplyPositionId = _nextSupplyPositionId++;
        SupplyPosition storage supplyPosition = supplyPositions[supplyPositionId];
        supplyPosition.owner = msg.sender;
        supplyPosition.asset = asset;
        supplyPosition.amount = amount;
        supplyPosition.interestRateMode = interestRateMode;
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
            amount,
            interestRateMode
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

    /**
     * @notice Get all supply positions owned by a user
     * @param user The user address
     * @return Array of supply position IDs
     */
    function getUserSupplyPositions(address user) external view returns (uint256[] memory) {
        return _userSupplyPositions[user];
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
     * @notice Get all active supply positions owned by a user
     * @param user The user address
     * @return Array of active supply position IDs
     */
    function getUserActiveSupplyPositions(address user) external view returns (uint256[] memory) {
        uint256[] memory allSupplyPositions = _userSupplyPositions[user];
        
        // First, count active supply positions
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allSupplyPositions.length; i++) {
            if (supplyPositions[allSupplyPositions[i]].active) {
                activeCount++;
            }
        }
        
        // Create result array with exact size needed
        uint256[] memory activeSupplyPositions = new uint256[](activeCount);
        
        // Fill the result array
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < allSupplyPositions.length; i++) {
            if (supplyPositions[allSupplyPositions[i]].active) {
                activeSupplyPositions[resultIndex] = allSupplyPositions[i];
                resultIndex++;
            }
        }
        
        return activeSupplyPositions;
    }

    /**
     * @notice Get user supply positions with full details
     * @param user The user address
     * @return Array of SupplyPosition structs with full details
     */
    function getUserSupplyPositionsWithDetails(address user) external view returns (SupplyPosition[] memory) {
        uint256[] memory supplyPositionIds = _userSupplyPositions[user];
        SupplyPosition[] memory userSupplyPositions = new SupplyPosition[](supplyPositionIds.length);
        
        for (uint256 i = 0; i < supplyPositionIds.length; i++) {
            userSupplyPositions[i] = supplyPositions[supplyPositionIds[i]];
        }
        
        return userSupplyPositions;
    }

    /**
     * @notice Get total amount supplied for a specific asset
     * @param asset The address of the asset
     * @return The total amount supplied for the asset
     */
    function getTotalSuppliedByAsset(address asset) external view returns (uint256) {
        return totalSuppliedByAsset[asset];
    }
    
    /**
     * @notice Get the total number of active supply positions
     * @return The total count of active supply positions
     */
    function getTotalActiveSupplyPositions() external view returns (uint256) {
        return totalActiveSupplyPositions;
    }
    
    /**
     * @notice Get the total number of supply positions ever created
     * @return The total count of supply positions created (next supply position ID - 1)
     */
    function getTotalSupplyPositionsCreated() external view returns (uint256) {
        return _nextSupplyPositionId - 1;
    }
} 