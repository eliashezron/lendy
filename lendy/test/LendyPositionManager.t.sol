// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

contract ConcreteMockPool is MockPool {
    // This is a concrete implementation of MockPool that can be instantiated
}

contract LendyPositionManagerTest is Test {
    LendyPositionManager public positionManager;
    ConcreteMockPool public pool;
    
    // Test tokens
    MockERC20 public usdc;
    MockERC20 public dai;
    MockERC20 public weth;
    
    // Test users
    address public constant USER1 = address(1);
    address public constant USER2 = address(2);
    address public constant ADMIN = address(3);
    
    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        
        // Deploy mock Aave Pool
        pool = new ConcreteMockPool();
        
        // Set up reserve data for tokens
        DataTypes.ReserveData memory reserveData;
        reserveData.aTokenAddress = address(usdc);
        pool.setReserveData(address(usdc), reserveData);
        
        reserveData.aTokenAddress = address(dai);
        pool.setReserveData(address(dai), reserveData);
        
        reserveData.aTokenAddress = address(weth);
        pool.setReserveData(address(weth), reserveData);
        
        // Deploy LendyPositionManager
        positionManager = new LendyPositionManager(address(pool));
        
        // Set up test users with initial balances
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
        vm.deal(ADMIN, 100 ether);
        
        // Set up initial token balances for test users
        usdc.mint(USER1, 10000e6);  // 10,000 USDC
        dai.mint(USER1, 10000e18);  // 10,000 DAI
        weth.mint(USER1, 10e18);    // 10 WETH
        
        usdc.mint(USER2, 10000e6);  // 10,000 USDC
        dai.mint(USER2, 10000e18);  // 10,000 DAI
        weth.mint(USER2, 10e18);    // 10 WETH

        // Mint tokens to LendyPositionManager contract
        usdc.mint(address(positionManager), 10000e6);  // 10,000 USDC
        dai.mint(address(positionManager), 10000e18);  // 10,000 DAI
        weth.mint(address(positionManager), 10e18);    // 10 WETH

        // Set mock health factor to a healthy value
        pool.setMockHealthFactor(2e18); // 2.0 health factor
    }
    
    function _setupATokenBalance(address user, address asset, uint256 amount) internal {
        // Mint tokens to the pool
        MockERC20(asset).mint(address(pool), amount);
        
        // Set up the reserve data with proper aToken configuration
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);
        reserveData.aTokenAddress = asset;  // Set aToken address to the asset for simplicity
        reserveData.lastUpdateTimestamp = uint40(block.timestamp);
        pool.setReserveData(asset, reserveData);
        
        // Set the user's aToken balance in the pool
        pool.setUserATokenBalance(user, asset, amount);
    }
    
    function testCreatePosition() public {
        vm.startPrank(USER1);
        
        // Approve USDC for collateral
        usdc.approve(address(positionManager), 1000e6);
        
        // Create position with USDC as collateral and DAI as borrow
        uint256 positionId = positionManager.createPosition(
            address(usdc),   // collateral asset
            1000e6,          // collateral amount (1000 USDC)
            address(dai),    // borrow asset
            500e18,          // borrow amount (500 DAI)
            1                // stable interest rate mode
        );
        
        // Verify position creation
        assertEq(positionId, 1, "Position ID should be 1");
        assertEq(positionManager.totalActivePositions(), 1, "Total active positions should be 1");
        
        // Get position details
        (address owner, address collateralAsset, uint256 collateralAmount, 
         address borrowAsset, uint256 borrowAmount, uint256 interestRateMode, bool active) = 
            _getPositionDetails(positionId);
        
        assertEq(owner, USER1, "Position owner should be USER1");
        assertEq(collateralAsset, address(usdc), "Collateral asset should be USDC");
        assertEq(collateralAmount, 1000e6, "Collateral amount should be 1000 USDC");
        assertEq(borrowAsset, address(dai), "Borrow asset should be DAI");
        assertEq(borrowAmount, 500e18, "Borrow amount should be 500 DAI");
        assertEq(interestRateMode, 1, "Interest rate mode should be stable");
        assertTrue(active, "Position should be active");
        
        vm.stopPrank();
    }
    
    function testAddCollateral() public {
        // First create a position
        testCreatePosition();
        
        vm.startPrank(USER1);
        
        // Approve additional USDC for collateral
        usdc.approve(address(positionManager), 500e6);
        
        // Add more collateral
        positionManager.addCollateral(1, 500e6);
        
        // Verify updated position details
        (,,uint256 collateralAmount,,,,bool active) = _getPositionDetails(1);
        
        assertEq(collateralAmount, 1500e6, "Collateral amount should be 1500 USDC");
        assertTrue(active, "Position should still be active");
        
        vm.stopPrank();
    }
    
    function testWithdrawCollateral() public {
        // First create a position
        testCreatePosition();
        
        vm.startPrank(USER1);
        
        // Set up aToken balance for the position manager
        _setupATokenBalance(address(positionManager), address(usdc), 1000e6);
        
        // Withdraw some collateral
        uint256 withdrawnAmount = positionManager.withdrawCollateral(1, 200e6);
        
        // Verify updated position details
        (,,uint256 collateralAmount,,,,bool active) = _getPositionDetails(1);
        
        assertEq(withdrawnAmount, 200e6, "Withdrawn amount should be 200 USDC");
        assertEq(collateralAmount, 800e6, "Collateral amount should be 800 USDC");
        assertTrue(active, "Position should still be active");
        
        vm.stopPrank();
    }
    
    function testIncreaseBorrow() public {
        // First create a position
        testCreatePosition();
        
        vm.startPrank(USER1);
        
        // Increase borrow amount
        uint256 increasedAmount = positionManager.increaseBorrow(1, 200e18);
        
        // Verify updated position details
        (,,,,uint256 borrowAmount,,bool active) = _getPositionDetails(1);
        
        assertEq(increasedAmount, 200e18, "Increased borrow amount should be 200 DAI");
        assertEq(borrowAmount, 700e18, "Total borrow amount should be 700 DAI");
        assertTrue(active, "Position should still be active");
        
        vm.stopPrank();
    }
    
    function testRepayDebt() public {
        // First create a position
        testCreatePosition();
        
        vm.startPrank(USER1);
        
        // Approve DAI for repayment
        dai.approve(address(positionManager), 200e18);
        
        // Repay some debt
        positionManager.repayDebt(1, 200e18);
        
        // Verify updated position details
        (,,,,uint256 borrowAmount,,bool active) = _getPositionDetails(1);
        
        assertEq(borrowAmount, 300e18, "Remaining borrow amount should be 300 DAI");
        assertTrue(active, "Position should still be active");
        
        vm.stopPrank();
    }
    
    function testClosePosition() public {
        // First create a position
        testCreatePosition();
        
        vm.startPrank(USER1);
        
        // Ensure USER1 has enough DAI for repayment
        dai.mint(USER1, 500e18);  // Mint 500 DAI for repayment
        
        // Approve DAI for full repayment
        dai.approve(address(positionManager), 500e18);
        
        // Set mock health factor to ensure position is healthy
        pool.setMockHealthFactor(2e18);
        
        // Set up aToken balance for the position manager
        pool.supply(address(usdc), 1000e6, address(positionManager), 0);
        
        // Close position
        positionManager.closePosition(1);
        
        // Verify position is closed
        (,,,,,,bool active) = _getPositionDetails(1);
        assertFalse(active, "Position should be inactive");
        assertEq(positionManager.totalActivePositions(), 0, "Total active positions should be 0");
        
        vm.stopPrank();
    }
    
    function testLiquidatePosition() public {
        // First create a position
        testCreatePosition();
        
        // Simulate unhealthy position by setting low health factor
        pool.setMockHealthFactor(0.5e18); // 0.5 health factor
        
        vm.startPrank(USER2);
        
        // Set up aToken balance for the position manager
        _setupATokenBalance(address(positionManager), address(usdc), 1000e6);
        
        // Approve DAI for liquidation
        dai.approve(address(positionManager), 500e18);
        
        // Liquidate position
        (uint256 liquidatedCollateral, uint256 debtAmount) = positionManager.liquidatePosition(
            1,      // position ID
            500e18, // debt to cover
            false   // don't receive aToken
        );
        
        // Verify liquidation
        assertTrue(liquidatedCollateral > 0, "Should have liquidated some collateral");
        assertEq(debtAmount, 500e18, "Debt amount should be 500 DAI");
        
        // Verify position is closed
        (,,,,,,bool active) = _getPositionDetails(1);
        assertFalse(active, "Position should be inactive");
        
        vm.stopPrank();
    }
    
    function testGetUserPositions() public {
        // Create multiple positions for USER1
        vm.startPrank(USER1);
        
        // First position
        usdc.approve(address(positionManager), 1000e6);
        positionManager.createPosition(address(usdc), 1000e6, address(dai), 500e18, 1);
        
        // Second position
        weth.approve(address(positionManager), 1e18);
        positionManager.createPosition(address(weth), 1e18, address(usdc), 1000e6, 2);
        
        // Get all positions
        uint256[] memory positions = positionManager.getUserPositions(USER1);
        assertEq(positions.length, 2, "Should have 2 positions");
        
        // Get active positions
        uint256[] memory activePositions = positionManager.getUserActivePositions(USER1);
        assertEq(activePositions.length, 2, "Should have 2 active positions");
        
        vm.stopPrank();
    }
    
    // Helper function to get position details
    function _getPositionDetails(uint256 positionId) internal view returns (
        address owner,
        address collateralAsset,
        uint256 collateralAmount,
        address borrowAsset,
        uint256 borrowAmount,
        uint256 interestRateMode,
        bool active
    ) {
        LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
        return (
            position.owner,
            position.collateralAsset,
            position.collateralAmount,
            position.borrowAsset,
            position.borrowAmount,
            position.interestRateMode,
            position.active
        );
    }
} 