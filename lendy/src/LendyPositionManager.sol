// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LendyProtocol} from "./LendyProtocol.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/**
 * @title LendyPositionManager
 * @author eliashezron
 * @notice Contract for managing user lending and borrowing positions
 * @dev This contract allows users to create positions with specific collateral and borrow parameters
 */
contract LendyPositionManager is Ownable {
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

    // The Lendy Protocol contract
    LendyProtocol public lendyProtocol;

    // Position ID counter
    uint256 private _nextPositionId;

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

    event DebtRepaid(uint256 indexed positionId, uint256 amount);

    // ============ Constructor ============

    /**
     * @param _lendyProtocol The address of the LendyProtocol contract
     */
    constructor(address _lendyProtocol) Ownable(msg.sender) {
        lendyProtocol = LendyProtocol(_lendyProtocol);
        _nextPositionId = 1;
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

        // Transfer collateral from user and supply to Aave via LendyProtocol
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
        SafeERC20.forceApprove(IERC20(collateralAsset), address(lendyProtocol), collateralAmount);
        lendyProtocol.supply(collateralAsset, collateralAmount, address(this), 0);

        // Set collateral to be used as collateral
        lendyProtocol.setUserUseReserveAsCollateral(collateralAsset, true);

        // Borrow the specified asset on behalf of this contract
        lendyProtocol.borrow(borrowAsset, borrowAmount, interestRateMode, 0, address(this));

        // Transfer borrowed funds to the user
        IERC20(borrowAsset).safeTransfer(msg.sender, borrowAmount);

        emit PositionCreated(
            positionId,
            msg.sender,
            collateralAsset,
            collateralAmount,
            borrowAsset,
            borrowAmount,
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

        // Transfer additional collateral from user and supply to Aave via LendyProtocol
        IERC20(position.collateralAsset).safeTransferFrom(msg.sender, address(this), additionalAmount);
        SafeERC20.forceApprove(IERC20(position.collateralAsset), address(lendyProtocol), additionalAmount);
        lendyProtocol.supply(position.collateralAsset, additionalAmount, address(this), 0);

        // Update position collateral amount
        position.collateralAmount += additionalAmount;

        emit CollateralAdded(positionId, additionalAmount);
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
        
        // Repay debt on Aave via LendyProtocol
        SafeERC20.forceApprove(IERC20(position.borrowAsset), address(lendyProtocol), amount);
        uint256 repaidAmount = lendyProtocol.repay(
            position.borrowAsset,
            amount,
            position.interestRateMode,
            address(this)
        );

        // Update position borrow amount
        if (amount >= position.borrowAmount) {
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

        // Check the current remaining debt
        (,,,,, uint256 healthFactor) = lendyProtocol.getUserAccountData(address(this));
        
        // Require healthy position
        require(healthFactor > 1e18, "Unhealthy position");

        // If there's any remaining debt, user needs to transfer it for repayment
        if (position.borrowAmount > 0) {
            IERC20(position.borrowAsset).safeTransferFrom(
                msg.sender,
                address(this),
                position.borrowAmount
            );
            
            // Repay the debt
            SafeERC20.forceApprove(IERC20(position.borrowAsset), address(lendyProtocol), position.borrowAmount);
            lendyProtocol.repay(
                position.borrowAsset,
                position.borrowAmount,
                position.interestRateMode,
                address(this)
            );
        }

        // Withdraw the collateral back to the user
        uint256 withdrawnAmount = lendyProtocol.withdraw(
            position.collateralAsset,
            type(uint256).max, // withdraw all
            msg.sender
        );

        // Mark position as inactive
        position.active = false;
        position.borrowAmount = 0;
        position.collateralAmount = 0;

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
} 