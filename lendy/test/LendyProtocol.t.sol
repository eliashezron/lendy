// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock contracts for testing
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";
import {MockPoolAddressesProvider} from "./mocks/MockPoolAddressesProvider.sol";
import {ConcreteMockPool} from "./mocks/ConcreteMockPool.sol";

contract LendyProtocolTest is Test {
    // Contracts
    LendyProtocol public lendyProtocol;
    LendyPositionManager public positionManager;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20Permit public dai; // Token that supports permit
    ConcreteMockPool public mockPool;
    MockPoolAddressesProvider public mockAddressesProvider;

    // Users
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    // Initial balances
    uint256 public constant INITIAL_BALANCE = 10_000 * 1e6; // 10,000 USDC
    uint256 public constant INITIAL_WETH = 10 * 1e18; // 10 WETH
    uint256 public constant INITIAL_DAI = 10_000 * 1e18; // 10,000 DAI

    // Permit parameters
    uint256 public constant PERMIT_DEADLINE = type(uint256).max;
    
    function setUp() public {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        dai = new MockERC20Permit("Dai Stablecoin", "DAI", 18);
        
        // Deploy mock Aave contracts
        mockPool = new ConcreteMockPool();
        mockAddressesProvider = new MockPoolAddressesProvider();
        mockAddressesProvider.setPool(address(mockPool));
        
        // Deploy Lendy contracts
        lendyProtocol = new LendyProtocol(address(mockAddressesProvider));
        positionManager = new LendyPositionManager(address(lendyProtocol));
        
        // Set up users
        vm.startPrank(alice);
        usdc.mint(alice, INITIAL_BALANCE);
        weth.mint(alice, INITIAL_WETH);
        dai.mint(alice, INITIAL_DAI);
        usdc.approve(address(lendyProtocol), type(uint256).max);
        weth.approve(address(lendyProtocol), type(uint256).max);
        dai.approve(address(lendyProtocol), type(uint256).max);
        usdc.approve(address(positionManager), type(uint256).max);
        weth.approve(address(positionManager), type(uint256).max);
        dai.approve(address(positionManager), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.mint(bob, INITIAL_BALANCE);
        weth.mint(bob, INITIAL_WETH);
        dai.mint(bob, INITIAL_DAI);
        usdc.approve(address(lendyProtocol), type(uint256).max);
        weth.approve(address(lendyProtocol), type(uint256).max);
        dai.approve(address(lendyProtocol), type(uint256).max);
        usdc.approve(address(positionManager), type(uint256).max);
        weth.approve(address(positionManager), type(uint256).max);
        dai.approve(address(positionManager), type(uint256).max);
        vm.stopPrank();
    }
    
    function testSupply() public {
        uint256 supplyAmount = 1000 * 1e6; // 1,000 USDC
        
        vm.startPrank(alice);
        lendyProtocol.supply(address(usdc), supplyAmount, alice, 0);
        vm.stopPrank();
        
        // Check that the supply call was forwarded to the mock pool
        assertEq(mockPool.lastSupplyAsset(), address(usdc));
        assertEq(mockPool.lastSupplyAmount(), supplyAmount);
        assertEq(mockPool.lastSupplyOnBehalfOf(), alice);
    }
    
    function testSupplyWithPermit() public {
        uint256 supplyAmount = 1000 * 1e18; // 1,000 DAI
        
        // Test parameters for permit
        uint8 v = 27;
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));
        
        vm.startPrank(alice);
        // Calling without prior approval, using permit directly
        lendyProtocol.supplyWithPermit(
            address(dai), 
            supplyAmount, 
            alice, 
            0, 
            PERMIT_DEADLINE, 
            v, 
            r, 
            s
        );
        vm.stopPrank();
        
        // Check that the supply call was forwarded to the mock pool
        assertEq(mockPool.lastSupplyAsset(), address(dai));
        assertEq(mockPool.lastSupplyAmount(), supplyAmount);
        assertEq(mockPool.lastSupplyOnBehalfOf(), alice);
    }
    
    function testWithdraw() public {
        uint256 supplyAmount = 1000 * 1e6; // 1,000 USDC
        uint256 withdrawAmount = 500 * 1e6; // 500 USDC
        
        // First supply
        vm.startPrank(alice);
        lendyProtocol.supply(address(usdc), supplyAmount, alice, 0);
        
        // Then withdraw
        uint256 withdrawnAmount = lendyProtocol.withdraw(address(usdc), withdrawAmount, alice);
        vm.stopPrank();
        
        // Check that the withdraw call was forwarded to the mock pool
        assertEq(mockPool.lastWithdrawAsset(), address(usdc));
        assertEq(mockPool.lastWithdrawAmount(), withdrawAmount);
        assertEq(mockPool.lastWithdrawTo(), alice);
        
        // The MockPool returns the same amount as requested for withdraw
        assertEq(withdrawnAmount, withdrawAmount);
    }
    
    function testBorrow() public {
        uint256 supplyAmount = 1000 * 1e6; // 1,000 USDC
        uint256 borrowAmount = 500 * 1e6; // 500 USDC
        uint256 interestRateMode = 2; // Variable rate
        
        // First supply
        vm.startPrank(alice);
        lendyProtocol.supply(address(usdc), supplyAmount, alice, 0);
        
        // Then borrow
        lendyProtocol.borrow(address(usdc), borrowAmount, interestRateMode, 0, alice);
        vm.stopPrank();
        
        // Check that the borrow call was forwarded to the mock pool
        assertEq(mockPool.lastBorrowAsset(), address(usdc));
        assertEq(mockPool.lastBorrowAmount(), borrowAmount);
        assertEq(mockPool.lastBorrowInterestRateMode(), interestRateMode);
        assertEq(mockPool.lastBorrowOnBehalfOf(), alice);
    }
    
    function testRepay() public {
        uint256 supplyAmount = 1000 * 1e6; // 1,000 USDC
        uint256 borrowAmount = 500 * 1e6; // 500 USDC
        uint256 repayAmount = 300 * 1e6; // 300 USDC
        uint256 interestRateMode = 2; // Variable rate
        
        // First supply
        vm.startPrank(alice);
        lendyProtocol.supply(address(usdc), supplyAmount, alice, 0);
        
        // Then borrow
        lendyProtocol.borrow(address(usdc), borrowAmount, interestRateMode, 0, alice);
        
        // Then repay
        uint256 repaidAmount = lendyProtocol.repay(address(usdc), repayAmount, interestRateMode, alice);
        vm.stopPrank();
        
        // Check that the repay call was forwarded to the mock pool
        assertEq(mockPool.lastRepayAsset(), address(usdc));
        assertEq(mockPool.lastRepayAmount(), repayAmount);
        assertEq(mockPool.lastRepayInterestRateMode(), interestRateMode);
        assertEq(mockPool.lastRepayOnBehalfOf(), alice);
        
        // The MockPool returns the same amount as requested for repay
        assertEq(repaidAmount, repayAmount);
    }
    
    function testRepayWithPermit() public {
        uint256 supplyAmount = 1000 * 1e18; // 1,000 DAI
        uint256 borrowAmount = 500 * 1e18; // 500 DAI
        uint256 repayAmount = 300 * 1e18; // 300 DAI
        uint256 interestRateMode = 2; // Variable rate
        
        // Test parameters for permit
        uint8 v = 27;
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));
        
        // First supply
        vm.startPrank(alice);
        lendyProtocol.supply(address(dai), supplyAmount, alice, 0);
        
        // Then borrow
        lendyProtocol.borrow(address(dai), borrowAmount, interestRateMode, 0, alice);
        
        // Then repay using permit
        uint256 repaidAmount = lendyProtocol.repayWithPermit(
            address(dai), 
            repayAmount, 
            interestRateMode, 
            alice, 
            PERMIT_DEADLINE, 
            v, 
            r, 
            s
        );
        vm.stopPrank();
        
        // Check that the repay call was forwarded to the mock pool
        assertEq(mockPool.lastRepayAsset(), address(dai));
        assertEq(mockPool.lastRepayAmount(), repayAmount);
        assertEq(mockPool.lastRepayInterestRateMode(), interestRateMode);
        assertEq(mockPool.lastRepayOnBehalfOf(), alice);
        
        // The MockPool returns the same amount as requested for repay
        assertEq(repaidAmount, repayAmount);
    }
    
    function testLiquidationCall() public {
        uint256 collateralAmount = 10 * 1e18; // 10 WETH
        uint256 borrowAmount = 5000 * 1e6; // 5,000 USDC
        uint256 debtToCover = 1000 * 1e6; // 1,000 USDC for liquidation
        
        // First, set up a position for bob that will be liquidated
        vm.startPrank(bob);
        lendyProtocol.supply(address(weth), collateralAmount, bob, 0);
        lendyProtocol.borrow(address(usdc), borrowAmount, 2, 0, bob);
        vm.stopPrank();
        
        // Set bob's health factor to an unhealthy level
        mockPool.setMockHealthFactor(0.9e18); // 0.9, which is below the 1.0 threshold
        
        // Alice will liquidate bob's position
        vm.startPrank(alice);
        (uint256 liquidatedCollateral, uint256 debt) = lendyProtocol.liquidationCall(
            address(weth),  // collateral asset
            address(usdc),  // debt asset
            bob,            // user to liquidate
            debtToCover,    // amount of debt to cover
            false           // receive aToken (false to receive the underlying asset)
        );
        vm.stopPrank();
        
        // Check the liquidation call was forwarded to the mock pool
        assertEq(mockPool.lastLiquidationCollateralAsset(), address(weth));
        assertEq(mockPool.lastLiquidationDebtAsset(), address(usdc));
        assertEq(mockPool.lastLiquidationUser(), bob);
        assertEq(mockPool.lastLiquidationDebtToCover(), debtToCover);
        assertEq(mockPool.lastLiquidationReceiveAToken(), false);
        
        // Check return values from our wrapper
        assertEq(debt, debtToCover);
        assertEq(liquidatedCollateral, debtToCover * 105 / 100); // 5% bonus
    }
    
    function testPositionManager() public {
        uint256 collateralAmount = 5 * 1e18; // 5 WETH
        uint256 borrowAmount = 1000 * 1e6; // 1,000 USDC
        uint256 interestRateMode = 2; // Variable rate
        
        // Mint tokens to the MockPool to simulate available liquidity for both assets
        usdc.mint(address(mockPool), 1000 * 1e6);
        weth.mint(address(mockPool), 10 * 1e18);
        
        // Also mint some USDC to the position manager to handle the safeTransfer call
        usdc.mint(address(positionManager), borrowAmount);
        
        vm.startPrank(alice);
        uint256 positionId = positionManager.createPosition(
            address(weth),
            collateralAmount,
            address(usdc),
            borrowAmount,
            interestRateMode
        );
        vm.stopPrank();
        
        // Check position details
        LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
        assertEq(position.owner, alice);
        assertEq(position.collateralAsset, address(weth));
        assertEq(position.collateralAmount, collateralAmount);
        assertEq(position.borrowAsset, address(usdc));
        assertEq(position.borrowAmount, borrowAmount);
        assertEq(position.interestRateMode, interestRateMode);
        assertEq(position.active, true);
        
        // Check that user positions array was updated
        uint256[] memory alicePositions = positionManager.getUserPositions(alice);
        assertEq(alicePositions.length, 1);
        assertEq(alicePositions[0], positionId);
    }
    
    function testLiquidatePosition() public {
        uint256 collateralAmount = 10 * 1e18; // 10 WETH
        uint256 borrowAmount = 5000 * 1e6; // 5,000 USDC
        uint256 debtToCover = 1000 * 1e6; // 1,000 USDC for liquidation
        uint256 interestRateMode = 2; // Variable rate
        
        // Mint tokens to the MockPool
        usdc.mint(address(mockPool), 5000 * 1e6);
        weth.mint(address(mockPool), 20 * 1e18);
        
        // Also mint USDC to the position manager
        usdc.mint(address(positionManager), borrowAmount);
        
        // First, Alice creates a position
        vm.startPrank(alice);
        uint256 positionId = positionManager.createPosition(
            address(weth),
            collateralAmount,
            address(usdc),
            borrowAmount,
            interestRateMode
        );
        vm.stopPrank();
        
        // Set health factor to an unhealthy level
        mockPool.setMockHealthFactor(0.9e18); // 0.9, which is below the 1.0 threshold
        
        // Bob will liquidate Alice's position
        vm.startPrank(bob);
        usdc.approve(address(positionManager), debtToCover);
        
        (uint256 liquidatedCollateral, uint256 debt) = positionManager.liquidatePosition(
            positionId,
            debtToCover,
            false
        );
        vm.stopPrank();
        
        // Check the position state after liquidation
        LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
        
        // Verify the expected changes
        assertEq(debt, debtToCover);
        assertEq(liquidatedCollateral, debtToCover * 105 / 100); // 5% bonus
        
        // The position should have reduced collateral and debt
        assertEq(position.borrowAmount, borrowAmount - debtToCover);
        assertEq(position.collateralAmount, collateralAmount - liquidatedCollateral);
        assertEq(position.active, true); // Position is still active after partial liquidation
    }

} 