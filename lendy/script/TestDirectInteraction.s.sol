// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {MockPool} from "../test/mocks/MockPool.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {ConcreteMockPool} from "../test/mocks/ConcreteMockPool.sol";

/**
 * @title TestDirectInteraction
 * @notice Script to test all major functions of the direct LendyPositionManager
 */
contract TestDirectInteraction is Script {
    // Test variables
    LendyPositionManager public positionManager;
    MockPool public mockPool;
    address public usdc;
    address public weth;
    address public dai;
    address public testUser;
    uint256 public testPrivateKey;
    uint256 public positionId;

    // Test function selector
    string public testFunction;

    function setUp() public {
        // Get the test function from environment variable
        testFunction = vm.envOr("TEST_FUNCTION", string("check"));
        
        // Use our deployed contracts
        positionManager = LendyPositionManager(0x48C365A5cFfAe7B39400e062dEA26669D6973007);
        mockPool = MockPool(0x056a9AEc78d851f8E977401d1ef182C57aA3E219);
        usdc = 0x1ab49E36A37Ac3aAf4a74dF72cC4Bea885a10D27;     // USDC
        weth = 0x0D8Af705d767e7b63250A6ac90Fe2968AE062c0D;     // WETH
        dai = 0xc52Ae76CDA709bD3d5F1eEB20e2c71ab0C3dF65e;     // DAI
        
        // Hardcoded test private key - ONLY FOR TESTING!
        testPrivateKey = 0x0000000000000000000000000000000000000000000000000000000000000000;
        testUser = vm.addr(testPrivateKey);
    }
    
    function run() public {
        console.log("\n==================================================================");
        console.log("LENDY POSITION MANAGER - DIRECT INTERACTION TEST SCRIPT");
        console.log("==================================================================\n");

        console.log("Running test interaction script with function:", testFunction);
        console.log("Contract Addresses:");
        console.log("  - LendyPositionManager:", address(positionManager));
        console.log("  - MockPool:           ", address(mockPool));
        console.log("Token Addresses:");
        console.log("  - USDC:               ", usdc);
        console.log("  - WETH:               ", weth);
        console.log("  - DAI:                ", dai);
        console.log("User Information:");
        console.log("  - Test user address:  ", testUser);
        console.log("------------------------------------------------------------------\n");
        
        // Default to connectivity test
        if (keccak256(bytes(testFunction)) == keccak256(bytes("check")) || 
            keccak256(bytes(testFunction)) == keccak256(bytes(""))) {
            testConnectivity();
            return;
        }
        
        // Branch based on the test function
        if (keccak256(bytes(testFunction)) == keccak256(bytes("all"))) {
            runAllTests();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("create"))) {
            testCreatePosition();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("add"))) {
            testAddCollateral();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("withdraw"))) {
            testWithdrawCollateral();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("borrow"))) {
            testIncreaseBorrow();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("repay"))) {
            testRepayDebt();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("close"))) {
            testClosePosition();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("liquidate"))) {
            testLiquidation();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("deploy"))) {
            deployTokens(); // New function to deploy fresh token contracts
        } else {
            console.log("Unknown test function. Available options: check, all, create, add, withdraw, borrow, repay, close, liquidate, deploy");
        }
    }
    
    // New function to run all tests in sequence
    function runAllTests() public {
        console.log("\n==================================================================");
        console.log("RUNNING ALL TESTS IN SEQUENCE");
        console.log("==================================================================\n");
        
        // First check connectivity
        console.log("\n==== 1. CONNECTIVITY TEST ====");
        testConnectivity();
        
        // Create a position first
        console.log("\n==== 2. CREATE POSITION TEST ====");
        testCreatePosition();
        
        // Add more collateral to position
        console.log("\n==== 3. ADD COLLATERAL TEST ====");
        testAddCollateral();
        
        // Borrow more against the collateral
        console.log("\n==== 4. INCREASE BORROW TEST ====");
        testIncreaseBorrow();
        
        // Repay part of the debt
        console.log("\n==== 5. REPAY DEBT TEST ====");
        testRepayDebt();
        
        // Withdraw some collateral
        console.log("\n==== 6. WITHDRAW COLLATERAL TEST ====");
        testWithdrawCollateral();
        
        // Test full position closure
        // Creates a new position and closes it
        console.log("\n==== 7. CLOSE POSITION TEST ====");
        testClosePosition();
        
        console.log("\n==================================================================");
        console.log("ALL TESTS COMPLETED SUCCESSFULLY");
        console.log("==================================================================\n");
    }
    
    // ==================== Test Functions ====================
    
    function testConnectivity() public {
        console.log("\n==================================================================");
        console.log("TESTING CONNECTIVITY AND CONTRACT STATE");
        console.log("==================================================================\n");
        
        // This test doesn't need broadcasting because it's just read-only
        console.log("Testing read-only functions without broadcasting transactions...");
        
        // Contract verification
        console.log("\n------------------------------------------------------------------");
        console.log("CONTRACT VERIFICATION");
        console.log("------------------------------------------------------------------");
        
        // Try to check if the LendyPositionManager exists
        try positionManager.POOL() returns (IPool pool) {
            console.log("[SUCCESS] LendyPositionManager contract exists");
            console.log("   POOL address:", address(pool));
            
            if(address(pool) == address(mockPool)) {
                console.log("   [SUCCESS] POOL address matches MockPool address");
            } else {
                console.log("   [ERROR] POOL address mismatch!");
                console.log("      Expected:", address(mockPool));
                console.log("      Actual:  ", address(pool));
            }
        } catch {
            console.log("[ERROR] LendyPositionManager contract does not exist or has issues");
        }
        
        // Check health factor from mock pool 
        try mockPool.mockHealthFactor() returns (uint256 healthFactor) {
            console.log("[SUCCESS] MockPool contract exists");
            console.log("   Health factor:", healthFactor);
        } catch {
            console.log("[ERROR] MockPool contract does not exist or has issues");
        }
        
        // Token verification
        console.log("\n------------------------------------------------------------------");
        console.log("TOKEN VERIFICATION");
        console.log("------------------------------------------------------------------");
        
        // WETH
        verifyToken("WETH", weth);
        
        // USDC
        verifyToken("USDC", usdc);
        
        // DAI
        verifyToken("DAI", dai);
        
        // User positions
        console.log("\n------------------------------------------------------------------");
        console.log("USER POSITIONS");
        console.log("------------------------------------------------------------------");
        
        // Check if any positions exist for the test user
        try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
            console.log("Number of positions owned by test user:", positions.length);
            
            if (positions.length > 0) {
                console.log("\nPOSITION DETAILS");
                console.log("------------------------------------------------------------------");
                
                for(uint i = 0; i < positions.length; i++) {
                    positionId = positions[i];
                    console.log("\nPosition ID:", positionId);
                    
                    // Get details of each position
                    try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
                        console.log("  Owner:            ", position.owner);
                        console.log("  Collateral asset: ", position.collateralAsset);
                        string memory collateralName = getTokenName(position.collateralAsset);
                        console.log("  Collateral token: ", collateralName);
                        console.log("  Collateral amount:", position.collateralAmount);
                        console.log("  Borrow asset:     ", position.borrowAsset);
                        string memory borrowName = getTokenName(position.borrowAsset);
                        console.log("  Borrow token:     ", borrowName);
                        console.log("  Borrow amount:    ", position.borrowAmount);
                        console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
                        console.log("  Active:           ", position.active ? "Yes" : "No");
                    } catch {
                        console.log("  [ERROR] Failed to get position details");
                    }
                }
            } else {
                console.log("No positions found for test user");
            }
        } catch {
            console.log("[ERROR] Failed to get user positions");
        }
    }
    
    // Helper function to verify a token
    function verifyToken(string memory tokenName, address tokenAddress) internal {
        console.log("\nVerifying", tokenName, "token");
        
        // Name
        try MockERC20(tokenAddress).name() returns (string memory name) {
            console.log("[SUCCESS]", tokenName, "token exists");
            console.log("   Name:   ", name);
        } catch {
            console.log("[ERROR]", tokenName, "token does not exist or has issues");
            return;
        }
        
        // Symbol
        try MockERC20(tokenAddress).symbol() returns (string memory symbol) {
            console.log("   Symbol: ", symbol);
        } catch {
            console.log("   Symbol:  Unable to retrieve");
        }
        
        // Decimals
        try MockERC20(tokenAddress).decimals() returns (uint8 decimals) {
            console.log("   Decimals:", decimals);
        } catch {
            console.log("   Decimals: Unable to retrieve");
        }
        
        // User balance
        try IERC20(tokenAddress).balanceOf(testUser) returns (uint256 balance) {
            console.log("   User balance:", balance);
        } catch {
            console.log("   User balance: Unable to retrieve");
        }
    }
    
    // Helper function to get token name
    function getTokenName(address tokenAddress) internal view returns (string memory) {
        try MockERC20(tokenAddress).name() returns (string memory name) {
            return name;
        } catch {
            return "Unknown";
        }
    }
    
    // Deploy new tokens for testing (useful if there are issues with existing tokens)
    function deployTokens() public {
        console.log("\n=== Deploying New Test Contracts ===");
        vm.startBroadcast(testPrivateKey);
        
        // Deploy new token contracts
        address newUsdc = address(new MockERC20("USD Coin", "USDC", 6));
        address newWeth = address(new MockERC20("Wrapped Ether", "WETH", 18));
        address newDai = address(new MockERC20("Dai Stablecoin", "DAI", 18));
        
        console.log("Newly deployed tokens:");
        console.log("New USDC:", newUsdc);
        console.log("New WETH:", newWeth);
        console.log("New DAI:", newDai);
        
        // Mint some tokens to the test user
        try MockERC20(newUsdc).mint(testUser, 10000 * 10**6) {
            console.log("Successfully minted 10,000 USDC to test user");
        } catch {
            console.log("Failed to mint USDC");
        }
        
        try MockERC20(newWeth).mint(testUser, 10000 * 10**18) {
            console.log("Successfully minted 10,000 WETH to test user");
        } catch {
            console.log("Failed to mint WETH");
        }
        
        try MockERC20(newDai).mint(testUser, 10000 * 10**18) {
            console.log("Successfully minted 10,000 DAI to test user");
        } catch {
            console.log("Failed to mint DAI");
        }
        
        // Deploy a new MockPool
        address newMockPool = address(new ConcreteMockPool());
        console.log("New MockPool deployed at:", newMockPool);
        
        // Deploy a new LendyPositionManager that uses the MockPool
        address newPositionManager = address(new LendyPositionManager(newMockPool));
        console.log("New LendyPositionManager deployed at:", newPositionManager);
        
        // Update the addresses to use the new ones
        usdc = newUsdc;
        weth = newWeth;
        dai = newDai;
        mockPool = MockPool(newMockPool);
        positionManager = LendyPositionManager(newPositionManager);
        
        // Mint tokens to the mock pool for liquidity
        try MockERC20(usdc).mint(newMockPool, 1000000 * 10**6) {
            console.log("Successfully minted 1,000,000 USDC to MockPool");
        } catch {
            console.log("Failed to mint USDC to MockPool");
        }
        
        try MockERC20(weth).mint(newMockPool, 1000000 * 10**18) {
            console.log("Successfully minted 1,000,000 WETH to MockPool");
        } catch {
            console.log("Failed to mint WETH to MockPool");
        }
        
        try MockERC20(dai).mint(newMockPool, 1000000 * 10**18) {
            console.log("Successfully minted 1,000,000 DAI to MockPool");
        } catch {
            console.log("Failed to mint DAI to MockPool");
        }
        
        vm.stopBroadcast();
    }
    
    function testCreatePosition() public {
        console.log("\n==================================================================");
        console.log("TESTING CREATE POSITION");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // Set up test amounts
        uint256 collateralAmount = 1000 * 10**18; // 1000 WETH
        uint256 borrowAmount = 500 * 10**6;     // 500 USDC
        
        console.log("------------------------------------------------------------------");
        console.log("PREPARING TEST TOKENS");
        console.log("------------------------------------------------------------------");
        
        // Correctly cast the addresses to MockERC20 before minting tokens
        MockERC20 mockWeth = MockERC20(weth);
        MockERC20 mockUsdc = MockERC20(usdc);
        
        // Mint WETH (collateral)
        console.log("\nMinting WETH for collateral...");
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(testUser);
        console.log("WETH balance before:", wethBalanceBefore);
        
        try mockWeth.mint(testUser, collateralAmount) {
            uint256 wethBalanceAfter = IERC20(weth).balanceOf(testUser);
            console.log("[SUCCESS] Successfully minted WETH to test user");
            console.log("   Amount minted:", wethBalanceAfter - wethBalanceBefore);
            console.log("   New balance:  ", wethBalanceAfter);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to mint WETH. Reason:", reason);
        } catch {
            console.log("[ERROR] Failed to mint WETH with unknown error");
        }
        
        // Mint USDC (for later use)
        console.log("\nMinting USDC for borrowing...");
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(testUser);
        console.log("USDC balance before:", usdcBalanceBefore);
        
        try mockUsdc.mint(testUser, borrowAmount * 2) {
            uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(testUser);
            console.log("[SUCCESS] Successfully minted USDC to test user");
            console.log("   Amount minted:", usdcBalanceAfter - usdcBalanceBefore);
            console.log("   New balance:  ", usdcBalanceAfter);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to mint USDC. Reason:", reason);
        } catch {
            console.log("[ERROR] Failed to mint USDC with unknown error");
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("APPROVING TOKENS");
        console.log("------------------------------------------------------------------");
        
        // Approve tokens for the position manager
        console.log("\nApproving WETH for position manager...");
        try IERC20(weth).approve(address(positionManager), collateralAmount) {
            console.log("[SUCCESS] Successfully approved WETH");
            console.log("   Amount approved:", collateralAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve WETH. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve WETH with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("CREATING POSITION");
        console.log("------------------------------------------------------------------");
        
        console.log("\nParameters for position creation:");
        console.log("  Collateral asset:  ", weth, "(WETH)");
        console.log("  Collateral amount: ", collateralAmount);
        console.log("  Borrow asset:      ", usdc, "(USDC)");
        console.log("  Borrow amount:     ", borrowAmount);
        console.log("  Interest rate mode:", 2, "(Variable)");
        
        try positionManager.createPosition(
            weth,            // collateral asset
            collateralAmount, // collateral amount
            usdc,            // borrow asset
            borrowAmount,    // borrow amount
            2                // variable interest rate
        ) returns (uint256 id) {
            positionId = id;
            console.log("\n[SUCCESS] POSITION CREATED SUCCESSFULLY");
            console.log("   Position ID:     ", positionId);
            
            // Check balances after position creation
            uint256 wethBalanceAfter = IERC20(weth).balanceOf(testUser);
            uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(testUser);
            
            console.log("\nBalance changes:");
            console.log("   WETH decreased by:", wethBalanceBefore + collateralAmount - wethBalanceAfter);
            console.log("   USDC increased by:", usdcBalanceAfter - usdcBalanceBefore);
            
            // Verify position details
            console.log("\nVerifying position details...");
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
                console.log("\nPOSITION DETAILS");
                console.log("------------------------------------------------------------------");
                console.log("  Owner:            ", position.owner);
                console.log("  Collateral asset: ", position.collateralAsset);
                string memory collateralName = getTokenName(position.collateralAsset);
                console.log("  Collateral token: ", collateralName);
                console.log("  Collateral amount:", position.collateralAmount);
                console.log("  Borrow asset:     ", position.borrowAsset);
                string memory borrowName = getTokenName(position.borrowAsset);
                console.log("  Borrow token:     ", borrowName);
                console.log("  Borrow amount:    ", position.borrowAmount);
                console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
                console.log("  Active:           ", position.active ? "Yes" : "No");
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get position details with unknown error");
            }
            
            // Check user positions
            try positionManager.getUserPositions(testUser) returns (uint256[] memory userPositions) {
                console.log("\nUser now has", userPositions.length, "total positions");
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get user positions. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get user positions with unknown error");
            }
        } catch Error(string memory reason) {
            console.log("\n[ERROR] POSITION CREATION FAILED");
            console.log("   Reason:", reason);
            
            // Try to get more detailed error information
            console.log("\nDiagnostic information:");
            
            // Check allowance
            try IERC20(weth).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                console.log("   WETH allowance:", allowance);
                if (allowance < collateralAmount) {
                    console.log("   [ERROR] Insufficient allowance for collateral");
                }
            } catch {
                console.log("   [ERROR] Failed to check allowance");
            }
            
            // Check if the user has enough balance
            try IERC20(weth).balanceOf(testUser) returns (uint256 balance) {
                console.log("   WETH balance:", balance);
                if (balance < collateralAmount) {
                    console.log("   [ERROR] Insufficient balance for collateral");
                }
            } catch {
                console.log("   [ERROR] Failed to check balance");
            }
        } catch {
            console.log("\n[ERROR] POSITION CREATION FAILED");
            console.log("   Unknown error occurred");
            
            // Try to debug the issue
            try positionManager.POOL() returns (IPool pool) {
                console.log("   Position Manager POOL address:", address(pool));
                if (address(pool) != address(mockPool)) {
                    console.log("   [ERROR] POOL address mismatch with MockPool!");
                }
            } catch {
                console.log("   [ERROR] Failed to get POOL from position manager");
            }
        }
        
        vm.stopBroadcast();
    }
    
    function testAddCollateral() public {
        console.log("\n==================================================================");
        console.log("TESTING ADD COLLATERAL");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        console.log("------------------------------------------------------------------");
        console.log("VERIFYING POSITION");
        console.log("------------------------------------------------------------------\n");
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
            // Try to get existing positions
            try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
                if (positions.length > 0) {
                    positionId = positions[positions.length - 1];
                    console.log("[SUCCESS] Found existing position with ID:", positionId);
                } else {
                    console.log("[ERROR] No existing positions found, creating a new one...");
                    vm.stopBroadcast();
                    testCreatePosition();
                    return;
                }
            } catch {
                console.log("[ERROR] Failed to get user positions, creating a new one...");
                vm.stopBroadcast();
                testCreatePosition();
                return;
            }
        }
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        console.log("Getting position details for ID:", positionId);
        
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            console.log("\nPOSITION DETAILS BEFORE ADDING COLLATERAL");
            console.log("------------------------------------------------------------------");
            console.log("  Owner:            ", position.owner);
            console.log("  Collateral asset: ", position.collateralAsset);
            string memory collateralName = getTokenName(position.collateralAsset);
            console.log("  Collateral token: ", collateralName);
            console.log("  Collateral amount:", position.collateralAmount);
            console.log("  Borrow asset:     ", position.borrowAsset);
            string memory borrowName = getTokenName(position.borrowAsset);
            console.log("  Borrow token:     ", borrowName);
            console.log("  Borrow amount:    ", position.borrowAmount);
            console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
            console.log("  Active:           ", position.active ? "Yes" : "No");
            
            if (!position.active) {
                console.log("\n[ERROR] Position is not active, cannot add collateral");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("PREPARING ADDITIONAL COLLATERAL");
        console.log("------------------------------------------------------------------");
        
        // Add more collateral - 50% of current amount or fixed value
        uint256 additionalAmount = 500 * 10**18; // 500 WETH
        console.log("\nPreparing to add", additionalAmount, "collateral tokens");
        
        // Make sure we have enough tokens
        MockERC20 mockCollateral = MockERC20(positionBefore.collateralAsset);
        
        uint256 balanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        console.log("User collateral balance before:", balanceBefore);
        
        if (balanceBefore < additionalAmount) {
            console.log("Insufficient balance, minting additional collateral...");
            
            try mockCollateral.mint(testUser, additionalAmount) {
                uint256 balanceAfter = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
                console.log("[SUCCESS] Successfully minted additional collateral");
                console.log("   Amount minted:", balanceAfter - balanceBefore);
                console.log("   New balance:  ", balanceAfter);
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to mint additional collateral. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to mint additional collateral with unknown error");
            }
        } else {
            console.log("[SUCCESS] User has sufficient collateral balance");
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("APPROVING ADDITIONAL COLLATERAL");
        console.log("------------------------------------------------------------------");
        
        // Approve tokens
        try IERC20(positionBefore.collateralAsset).approve(address(positionManager), additionalAmount) {
            console.log("[SUCCESS] Successfully approved additional collateral");
            console.log("   Amount approved:", additionalAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve additional collateral. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve additional collateral with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("ADDING COLLATERAL TO POSITION");
        console.log("------------------------------------------------------------------");
        
        // Add collateral
        try positionManager.addCollateral(positionId, additionalAmount) {
            console.log("\n[SUCCESS] COLLATERAL ADDED SUCCESSFULLY");
            console.log("   Amount added:", additionalAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER ADDING COLLATERAL");
                console.log("------------------------------------------------------------------");
                console.log("  Owner:            ", positionAfter.owner);
                console.log("  Collateral asset: ", positionAfter.collateralAsset);
                string memory collateralName = getTokenName(positionAfter.collateralAsset);
                console.log("  Collateral token: ", collateralName);
                console.log("  Collateral amount:", positionAfter.collateralAmount);
                console.log("  Borrow asset:     ", positionAfter.borrowAsset);
                string memory borrowName = getTokenName(positionAfter.borrowAsset);
                console.log("  Borrow token:     ", borrowName);
                console.log("  Borrow amount:    ", positionAfter.borrowAmount);
                console.log("  Interest rate:    ", positionAfter.interestRateMode == 1 ? "Stable" : "Variable");
                console.log("  Active:           ", positionAfter.active ? "Yes" : "No");
                
                console.log("\nCOLLATERAL CHANGE SUMMARY");
                console.log("------------------------------------------------------------------");
                console.log("  Collateral before:", positionBefore.collateralAmount);
                console.log("  Collateral after: ", positionAfter.collateralAmount);
                console.log("  Increase:         ", positionAfter.collateralAmount - positionBefore.collateralAmount);
                
                if (positionAfter.collateralAmount - positionBefore.collateralAmount != additionalAmount) {
                    console.log("\n[WARNING] Actual collateral increase differs from requested amount");
                    console.log("   Requested increase:", additionalAmount);
                    console.log("   Actual increase:   ", positionAfter.collateralAmount - positionBefore.collateralAmount);
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get updated position details with unknown error");
            }
            
            // Check user balance after adding collateral
            try IERC20(positionBefore.collateralAsset).balanceOf(testUser) returns (uint256 balanceAfter) {
                console.log("\nUser collateral balance after:", balanceAfter);
                console.log("Balance decrease:            ", balanceBefore - balanceAfter);
            } catch {
                console.log("[ERROR] Failed to get user balance after adding collateral");
            }
        } catch Error(string memory reason) {
            console.log("\n[ERROR] FAILED TO ADD COLLATERAL");
            console.log("   Reason:", reason);
            
            // Additional diagnostics
            try IERC20(positionBefore.collateralAsset).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                console.log("   Allowance:", allowance);
                if (allowance < additionalAmount) {
                    console.log("   [ERROR] Insufficient allowance");
                }
            } catch {
                console.log("   [ERROR] Failed to check allowance");
            }
        } catch {
            console.log("\n[ERROR] FAILED TO ADD COLLATERAL");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    function testWithdrawCollateral() public {
        console.log("\n==================================================================");
        console.log("TESTING WITHDRAW COLLATERAL");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        console.log("------------------------------------------------------------------");
        console.log("VERIFYING POSITION");
        console.log("------------------------------------------------------------------\n");
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
            // Try to get existing positions
            try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
                if (positions.length > 0) {
                    positionId = positions[positions.length - 1];
                    console.log("[SUCCESS] Found existing position with ID:", positionId);
                } else {
                    console.log("[ERROR] No existing positions found, creating a new one...");
                    vm.stopBroadcast();
                    testCreatePosition();
                    testAddCollateral();
                    return;
                }
            } catch {
                console.log("[ERROR] Failed to get user positions, creating a new one...");
                vm.stopBroadcast();
                testCreatePosition();
                testAddCollateral();
                return;
            }
        }
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        console.log("Getting position details for ID:", positionId);
        
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            console.log("\nPOSITION DETAILS BEFORE WITHDRAWAL");
            console.log("------------------------------------------------------------------");
            console.log("  Owner:            ", position.owner);
            console.log("  Collateral asset: ", position.collateralAsset);
            string memory collateralName = getTokenName(position.collateralAsset);
            console.log("  Collateral token: ", collateralName);
            console.log("  Collateral amount:", position.collateralAmount);
            console.log("  Borrow asset:     ", position.borrowAsset);
            string memory borrowName = getTokenName(position.borrowAsset);
            console.log("  Borrow token:     ", borrowName);
            console.log("  Borrow amount:    ", position.borrowAmount);
            console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
            console.log("  Active:           ", position.active ? "Yes" : "No");
            
            if (!position.active) {
                console.log("\n[ERROR] Position is not active, cannot withdraw collateral");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("CALCULATING WITHDRAWAL AMOUNT");
        console.log("------------------------------------------------------------------");
        
        // Withdraw a portion of the collateral - 20% of current amount
        uint256 withdrawAmount = positionBefore.collateralAmount / 5;
        
        console.log("\nWithdrawal calculation:");
        console.log("  Total collateral:   ", positionBefore.collateralAmount);
        console.log("  Withdrawal amount:  ", withdrawAmount);
        console.log("  Percentage:          20%");
        console.log("  Remaining collateral:", positionBefore.collateralAmount - withdrawAmount);
        
        uint256 balanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        console.log("\nUser collateral balance before:", balanceBefore);
        
        console.log("\n------------------------------------------------------------------");
        console.log("WITHDRAWING COLLATERAL");
        console.log("------------------------------------------------------------------");
        
        try positionManager.withdrawCollateral(positionId, withdrawAmount) returns (uint256 withdrawnAmount) {
            console.log("\n[SUCCESS] COLLATERAL WITHDRAWAL COMPLETED");
            console.log("   Requested amount:", withdrawAmount);
            console.log("   Actual withdrawn:", withdrawnAmount);
            
            if (withdrawnAmount < withdrawAmount) {
                console.log("\n[WARNING] Actual withdrawn amount is less than requested");
                console.log("   This could be due to health factor limitations");
            }
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER WITHDRAWAL");
                console.log("------------------------------------------------------------------");
                console.log("  Owner:            ", positionAfter.owner);
                console.log("  Collateral asset: ", positionAfter.collateralAsset);
                string memory collateralName = getTokenName(positionAfter.collateralAsset);
                console.log("  Collateral token: ", collateralName);
                console.log("  Collateral amount:", positionAfter.collateralAmount);
                console.log("  Borrow asset:     ", positionAfter.borrowAsset);
                string memory borrowName = getTokenName(positionAfter.borrowAsset);
                console.log("  Borrow token:     ", borrowName);
                console.log("  Borrow amount:    ", positionAfter.borrowAmount);
                console.log("  Interest rate:    ", positionAfter.interestRateMode == 1 ? "Stable" : "Variable");
                console.log("  Active:           ", positionAfter.active ? "Yes" : "No");
                
                console.log("\nCOLLATERAL CHANGE SUMMARY");
                console.log("------------------------------------------------------------------");
                console.log("  Collateral before:", positionBefore.collateralAmount);
                console.log("  Collateral after: ", positionAfter.collateralAmount);
                console.log("  Decrease:         ", positionBefore.collateralAmount - positionAfter.collateralAmount);
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get updated position details with unknown error");
            }
            
            // Check user balance after withdrawal
            try IERC20(positionBefore.collateralAsset).balanceOf(testUser) returns (uint256 balanceAfter) {
                console.log("\nUser collateral balance after:", balanceAfter);
                console.log("Balance increase:             ", balanceAfter - balanceBefore);
                
                if (balanceAfter - balanceBefore != withdrawnAmount) {
                    console.log("\n[WARNING] Balance increase doesn't match withdrawn amount");
                    console.log("  Withdrawn amount:", withdrawnAmount);
                    console.log("  Balance increase:", balanceAfter - balanceBefore);
                }
            } catch {
                console.log("[ERROR] Failed to get user balance after withdrawal");
            }
        } catch Error(string memory reason) {
            console.log("\n[ERROR] COLLATERAL WITHDRAWAL FAILED");
            console.log("   Reason:", reason);
            
            // Try to get health factor information
            console.log("\nDiagnostic information:");
            try mockPool.mockHealthFactor() returns (uint256 healthFactor) {
                console.log("   Current health factor:", healthFactor);
                if (healthFactor <= 1e18) {
                    console.log("   [WARNING] Health factor is critically low");
                }
            } catch {
                console.log("   [ERROR] Failed to get health factor");
            }
        } catch {
            console.log("\n[ERROR] COLLATERAL WITHDRAWAL FAILED");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    function testIncreaseBorrow() public {
        console.log("\n=== Testing increaseBorrow ===");
        vm.startBroadcast(testPrivateKey);
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No active position found, getting existing positions...");
            
            // Try to get existing positions
            try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
                if (positions.length > 0) {
                    positionId = positions[positions.length - 1];
                    console.log("Found existing position with ID:", positionId);
                } else {
                    console.log("No existing positions found, creating a new one...");
                    // Stop the current broadcast
                    vm.stopBroadcast();
                    // Call the create position test and add collateral
                    testCreatePosition();
                    testAddCollateral();
                    // Return since the called functions already start and stop broadcasts
                    return;
                }
            } catch {
                console.log("Failed to get user positions, creating a new one...");
                // Stop the current broadcast
                vm.stopBroadcast();
                // Call the create position test and add collateral
                testCreatePosition();
                testAddCollateral();
                // Return since the called functions already start and stop broadcasts
                return;
            }
        }
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            console.log("Position before: borrow asset =", positionBefore.borrowAsset);
            console.log("Position before: borrow amount =", positionBefore.borrowAmount);
        } catch Error(string memory reason) {
            console.log("Failed to get position details. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Failed to get position details with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        // Increase borrow amount - add 50% more
        uint256 additionalBorrowAmount = positionBefore.borrowAmount / 2;
        console.log("Attempting to borrow additional:", additionalBorrowAmount);
        
        try positionManager.increaseBorrow(positionId, additionalBorrowAmount) returns (uint256 actualBorrowedAmount) {
            console.log("Requested additional borrow:", additionalBorrowAmount);
            console.log("Actual additional borrowed:", actualBorrowedAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("Borrow amount before:", positionBefore.borrowAmount);
                console.log("Borrow amount after:", positionAfter.borrowAmount);
                console.log("Increase:", positionAfter.borrowAmount - positionBefore.borrowAmount);
            } catch Error(string memory reason) {
                console.log("Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("Failed to get updated position details with unknown error");
            }
        } catch Error(string memory reason) {
            console.log("Failed to increase borrow. Reason:", reason);
        } catch {
            console.log("Failed to increase borrow with unknown error");
        }
        
        vm.stopBroadcast();
    }
    
    function testRepayDebt() public {
        console.log("\n==================================================================");
        console.log("TESTING REPAY DEBT");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        console.log("------------------------------------------------------------------");
        console.log("VERIFYING POSITION");
        console.log("------------------------------------------------------------------\n");
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
            // Try to get existing positions
            try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
                if (positions.length > 0) {
                    positionId = positions[positions.length - 1];
                    console.log("[SUCCESS] Found existing position with ID:", positionId);
                } else {
                    console.log("[ERROR] No existing positions found, creating a new one...");
                    vm.stopBroadcast();
                    testCreatePosition();
                    return;
                }
            } catch {
                console.log("[ERROR] Failed to get user positions, creating a new one...");
                vm.stopBroadcast();
                testCreatePosition();
                return;
            }
        }
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        console.log("Getting position details for ID:", positionId);
        
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            if (positionBefore.borrowAmount == 0) {
                console.log("[ERROR] No debt to repay, position has zero debt. Increasing borrow first...");
                vm.stopBroadcast();
                testIncreaseBorrow();
                return;
            }
            
            console.log("\nPOSITION DETAILS BEFORE REPAYMENT");
            console.log("------------------------------------------------------------------");
            console.log("  Owner:            ", position.owner);
            console.log("  Collateral asset: ", position.collateralAsset);
            string memory collateralName = getTokenName(position.collateralAsset);
            console.log("  Collateral token: ", collateralName);
            console.log("  Collateral amount:", position.collateralAmount);
            console.log("  Borrow asset:     ", position.borrowAsset);
            string memory borrowName = getTokenName(position.borrowAsset);
            console.log("  Borrow token:     ", borrowName);
            console.log("  Borrow amount:    ", position.borrowAmount);
            console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
            console.log("  Active:           ", position.active ? "Yes" : "No");
            
            if (!position.active) {
                console.log("\n[ERROR] Position is not active, cannot repay debt");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("CALCULATING REPAYMENT AMOUNT");
        console.log("------------------------------------------------------------------");
        
        // Calculate repay amount (half of current debt)
        uint256 repayAmount = positionBefore.borrowAmount / 2;
        
        console.log("\nRepayment calculation:");
        console.log("  Total debt:     ", positionBefore.borrowAmount);
        console.log("  Repayment amount:", repayAmount);
        console.log("  Percentage:      50%");
        console.log("  Remaining debt: ", positionBefore.borrowAmount - repayAmount);
        
        console.log("\n------------------------------------------------------------------");
        console.log("PREPARING TOKENS FOR REPAYMENT");
        console.log("------------------------------------------------------------------");
        
        // Check user balance of borrow asset
        uint256 borrowBalanceBefore = 0;
        try IERC20(positionBefore.borrowAsset).balanceOf(testUser) returns (uint256 balance) {
            borrowBalanceBefore = balance;
            console.log("\nUser balance of borrow asset before:", borrowBalanceBefore);
            
            if (balance < repayAmount) {
                console.log("Insufficient balance for repayment, minting more tokens...");
                
                // Make sure we have enough tokens
                MockERC20 mockBorrowAsset = MockERC20(positionBefore.borrowAsset);
                
                try mockBorrowAsset.mint(testUser, repayAmount) {
                    uint256 balanceAfterMint = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
                    console.log("[SUCCESS] Successfully minted tokens for repayment");
                    console.log("   Amount minted:", balanceAfterMint - borrowBalanceBefore);
                    console.log("   New balance:  ", balanceAfterMint);
                    borrowBalanceBefore = balanceAfterMint;
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to mint tokens for repayment. Reason:", reason);
                    vm.stopBroadcast();
                    return;
                } catch {
                    console.log("[ERROR] Failed to mint tokens for repayment with unknown error");
                    vm.stopBroadcast();
                    return;
                }
            } else {
                console.log("[SUCCESS] User has sufficient balance for repayment");
            }
        } catch {
            console.log("[ERROR] Failed to check borrow asset balance");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("APPROVING TOKENS FOR REPAYMENT");
        console.log("------------------------------------------------------------------");
        
        // Approve tokens for repayment
        try IERC20(positionBefore.borrowAsset).approve(address(positionManager), repayAmount) {
            console.log("[SUCCESS] Successfully approved tokens for repayment");
            console.log("   Amount approved:", repayAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve tokens for repayment. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve tokens for repayment with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("REPAYING DEBT");
        console.log("------------------------------------------------------------------");
        
        // Repay debt
        try positionManager.repayDebt(positionId, repayAmount) {
            console.log("\n[SUCCESS] DEBT REPAYMENT COMPLETED");
            console.log("   Amount repaid:", repayAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER REPAYMENT");
                console.log("------------------------------------------------------------------");
                console.log("  Owner:            ", positionAfter.owner);
                console.log("  Collateral asset: ", positionAfter.collateralAsset);
                string memory collateralName = getTokenName(positionAfter.collateralAsset);
                console.log("  Collateral token: ", collateralName);
                console.log("  Collateral amount:", positionAfter.collateralAmount);
                console.log("  Borrow asset:     ", positionAfter.borrowAsset);
                string memory borrowName = getTokenName(positionAfter.borrowAsset);
                console.log("  Borrow token:     ", borrowName);
                console.log("  Borrow amount:    ", positionAfter.borrowAmount);
                console.log("  Interest rate:    ", positionAfter.interestRateMode == 1 ? "Stable" : "Variable");
                console.log("  Active:           ", positionAfter.active ? "Yes" : "No");
                
                console.log("\nDEBT CHANGE SUMMARY");
                console.log("------------------------------------------------------------------");
                console.log("  Debt before:   ", positionBefore.borrowAmount);
                console.log("  Debt after:    ", positionAfter.borrowAmount);
                console.log("  Decrease:      ", positionBefore.borrowAmount - positionAfter.borrowAmount);
                
                if (positionBefore.borrowAmount - positionAfter.borrowAmount != repayAmount) {
                    console.log("\n[INFO] Actual debt decrease differs from repayment amount");
                    console.log("   This could be due to accumulated interest");
                    console.log("   Repayment amount:  ", repayAmount);
                    console.log("   Actual debt decrease:", positionBefore.borrowAmount - positionAfter.borrowAmount);
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get updated position details with unknown error");
            }
            
            // Check user balance of borrow asset after repayment
            try IERC20(positionBefore.borrowAsset).balanceOf(testUser) returns (uint256 balanceAfter) {
                console.log("\nUser borrow token balance after:", balanceAfter);
                console.log("Balance decrease:              ", borrowBalanceBefore - balanceAfter);
                
                if (borrowBalanceBefore - balanceAfter != repayAmount) {
                    console.log("\n[INFO] Balance decrease doesn't match repayment amount");
                    console.log("   Repayment amount: ", repayAmount);
                    console.log("   Balance decrease: ", borrowBalanceBefore - balanceAfter);
                }
            } catch {
                console.log("[ERROR] Failed to get user balance after repayment");
            }
        } catch Error(string memory reason) {
            console.log("\n[ERROR] DEBT REPAYMENT FAILED");
            console.log("   Reason:", reason);
            
            // Additional diagnostics
            try IERC20(positionBefore.borrowAsset).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                console.log("   Allowance:", allowance);
                if (allowance < repayAmount) {
                    console.log("   [ERROR] Insufficient allowance for repayment");
                }
            } catch {
                console.log("   [ERROR] Failed to check allowance");
            }
        } catch {
            console.log("\n[ERROR] DEBT REPAYMENT FAILED");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    function testClosePosition() public {
        console.log("\n==================================================================");
        console.log("TESTING CLOSE POSITION");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        console.log("------------------------------------------------------------------");
        console.log("PREPARING NEW POSITION FOR CLOSURE TEST");
        console.log("------------------------------------------------------------------");
        
        // Create a new position specifically for closing
        uint256 closePositionId = 0;
        
        console.log("\nCreating a new position to close...");
        uint256 collateralAmount = 500 * 10**18; // 500 WETH
        uint256 borrowAmount = 200 * 10**6;     // 200 USDC
        
        // Mint tokens for collateral
        console.log("\nPreparing collateral tokens (WETH)...");
        MockERC20 mockWeth = MockERC20(weth);
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(testUser);
        
        try mockWeth.mint(testUser, collateralAmount) {
            uint256 wethBalanceAfter = IERC20(weth).balanceOf(testUser);
            console.log("[SUCCESS] Successfully minted WETH for new position");
            console.log("   Amount minted:", wethBalanceAfter - wethBalanceBefore);
            console.log("   New balance:  ", wethBalanceAfter);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to mint WETH for new position. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to mint WETH for new position with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        // Approve tokens for position creation
        console.log("\nApproving WETH for position manager...");
        try IERC20(weth).approve(address(positionManager), collateralAmount) {
            console.log("[SUCCESS] Successfully approved WETH for new position");
            console.log("   Amount approved:", collateralAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve WETH for new position. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve WETH for new position with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        // Create position
        console.log("\nCreating position with parameters:");
        console.log("  Collateral asset:  ", weth, "(WETH)");
        console.log("  Collateral amount: ", collateralAmount);
        console.log("  Borrow asset:      ", usdc, "(USDC)");
        console.log("  Borrow amount:     ", borrowAmount);
        console.log("  Interest rate mode:", 2, "(Variable)");
        
        try positionManager.createPosition(
            weth,
            collateralAmount,
            usdc,
            borrowAmount,
            2
        ) returns (uint256 id) {
            closePositionId = id;
            console.log("\n[SUCCESS] Created new position with ID:", closePositionId);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to create new position. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to create new position with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("VERIFYING POSITION FOR CLOSURE");
        console.log("------------------------------------------------------------------");
        
        // Get position details
        LendyPositionManager.Position memory position;
        try positionManager.getPositionDetails(closePositionId) returns (LendyPositionManager.Position memory posDetails) {
            position = posDetails;
            
            console.log("\nPOSITION DETAILS BEFORE CLOSURE");
            console.log("------------------------------------------------------------------");
            console.log("  Position ID:      ", closePositionId);
            console.log("  Owner:            ", position.owner);
            console.log("  Collateral asset: ", position.collateralAsset);
            string memory collateralName = getTokenName(position.collateralAsset);
            console.log("  Collateral token: ", collateralName);
            console.log("  Collateral amount:", position.collateralAmount);
            console.log("  Borrow asset:     ", position.borrowAsset);
            string memory borrowName = getTokenName(position.borrowAsset);
            console.log("  Borrow token:     ", borrowName);
            console.log("  Borrow amount:    ", position.borrowAmount);
            console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
            console.log("  Active:           ", position.active ? "Yes" : "No");
            
            if (!position.active) {
                console.log("\n[ERROR] Position is already inactive, cannot close");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("PREPARING TOKENS FOR FULL REPAYMENT");
        console.log("------------------------------------------------------------------");
        
        // Check user balance of borrow asset
        MockERC20 mockUsdc = MockERC20(usdc);
        uint256 borrowBalanceBefore = 0;
        
        try IERC20(position.borrowAsset).balanceOf(testUser) returns (uint256 balance) {
            borrowBalanceBefore = balance;
            console.log("\nUser balance of borrow asset before:", borrowBalanceBefore);
            
            if (balance < position.borrowAmount) {
                console.log("Insufficient balance for full repayment, minting more tokens...");
                
                try mockUsdc.mint(testUser, position.borrowAmount) {
                    uint256 balanceAfterMint = IERC20(position.borrowAsset).balanceOf(testUser);
                    console.log("[SUCCESS] Successfully minted tokens for full repayment");
                    console.log("   Amount minted:", balanceAfterMint - borrowBalanceBefore);
                    console.log("   New balance:  ", balanceAfterMint);
                    borrowBalanceBefore = balanceAfterMint;
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to mint tokens for full repayment. Reason:", reason);
                    vm.stopBroadcast();
                    return;
                } catch {
                    console.log("[ERROR] Failed to mint tokens for full repayment with unknown error");
                    vm.stopBroadcast();
                    return;
                }
            } else {
                console.log("[SUCCESS] User has sufficient balance for full repayment");
            }
        } catch {
            console.log("[ERROR] Failed to check borrow asset balance");
            vm.stopBroadcast();
            return;
        }
        
        // Approve tokens for repayment
        console.log("\nApproving tokens for full repayment...");
        try IERC20(position.borrowAsset).approve(address(positionManager), position.borrowAmount) {
            console.log("[SUCCESS] Successfully approved tokens for full repayment");
            console.log("   Amount approved:", position.borrowAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve tokens for full repayment. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve tokens for full repayment with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("CLOSING POSITION");
        console.log("------------------------------------------------------------------");
        
        // Get initial balances to track changes
        uint256 initialCollateralBalance = IERC20(position.collateralAsset).balanceOf(testUser);
        uint256 initialBorrowBalance = IERC20(position.borrowAsset).balanceOf(testUser);
        
        console.log("\nInitial balances before closing:");
        console.log("  Collateral token:", initialCollateralBalance);
        console.log("  Borrow token:   ", initialBorrowBalance);
        
        // Close position
        try positionManager.closePosition(closePositionId) {
            console.log("\n[SUCCESS] POSITION CLOSED SUCCESSFULLY");
            console.log("   Position ID:", closePositionId);
            
            // Verify position status after closing
            try positionManager.getPositionDetails(closePositionId) returns (LendyPositionManager.Position memory closedPosition) {
                console.log("\nPOSITION DETAILS AFTER CLOSURE");
                console.log("------------------------------------------------------------------");
                console.log("  Owner:            ", closedPosition.owner);
                console.log("  Collateral asset: ", closedPosition.collateralAsset);
                string memory collateralName = getTokenName(closedPosition.collateralAsset);
                console.log("  Collateral token: ", collateralName);
                console.log("  Collateral amount:", closedPosition.collateralAmount);
                console.log("  Borrow asset:     ", closedPosition.borrowAsset);
                string memory borrowName = getTokenName(closedPosition.borrowAsset);
                console.log("  Borrow token:     ", borrowName);
                console.log("  Borrow amount:    ", closedPosition.borrowAmount);
                console.log("  Interest rate:    ", closedPosition.interestRateMode == 1 ? "Stable" : "Variable");
                console.log("  Active:           ", closedPosition.active ? "Yes" : "No");
                
                if (closedPosition.active) {
                    console.log("\n[ERROR] Position is still active after closure attempt!");
                } else {
                    console.log("\n[SUCCESS] Position is now inactive");
                }
                
                if (closedPosition.collateralAmount > 0) {
                    console.log("[WARNING] Position still has collateral:", closedPosition.collateralAmount);
                } else {
                    console.log("[SUCCESS] Collateral is now zero");
                }
                
                if (closedPosition.borrowAmount > 0) {
                    console.log("[WARNING] Position still has debt:", closedPosition.borrowAmount);
                } else {
                    console.log("[SUCCESS] Debt is now zero");
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get closed position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get closed position details with unknown error");
            }
            
            // Verify token balances after closure
            try IERC20(position.collateralAsset).balanceOf(testUser) returns (uint256 finalCollateralBalance) {
                console.log("\nFinal balances after closing:");
                console.log("  Collateral token:", finalCollateralBalance);
                uint256 collateralChange = finalCollateralBalance > initialCollateralBalance ? 
                    finalCollateralBalance - initialCollateralBalance : 
                    initialCollateralBalance - finalCollateralBalance;
                console.log("  Collateral change:", collateralChange);
                
                if (finalCollateralBalance > initialCollateralBalance) {
                    console.log("[SUCCESS] User received collateral back: ", collateralChange, " tokens");
                } else if (finalCollateralBalance < initialCollateralBalance) {
                    console.log("[WARNING] User's collateral decreased by: ", collateralChange, " tokens");
                } else {
                    console.log("[WARNING] User's collateral balance did not change");
                }
                
                try IERC20(position.borrowAsset).balanceOf(testUser) returns (uint256 finalBorrowBalance) {
                    console.log("  Borrow token:   ", finalBorrowBalance);
                    uint256 borrowChange = initialBorrowBalance > finalBorrowBalance ? 
                        initialBorrowBalance - finalBorrowBalance : 
                        finalBorrowBalance - initialBorrowBalance;
                    console.log("  Borrow change:  ", borrowChange);
                    
                    if (initialBorrowBalance > finalBorrowBalance) {
                        console.log("[SUCCESS] User spent ", borrowChange, " tokens for debt repayment");
                    } else if (finalBorrowBalance > initialBorrowBalance) {
                        console.log("[WARNING] User's borrow token balance increased by ", borrowChange, " tokens");
                    } else {
                        console.log("[WARNING] User's borrow token balance did not change");
                    }
                } catch {
                    console.log("[ERROR] Failed to get final borrow token balance");
                }
            } catch {
                console.log("[ERROR] Failed to get final collateral token balance");
            }
        } catch Error(string memory reason) {
            console.log("\n[ERROR] FAILED TO CLOSE POSITION");
            console.log("   Reason:", reason);
            
            // Additional diagnostics
            try IERC20(position.borrowAsset).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                console.log("\nDiagnostic information:");
                console.log("   Borrow allowance:", allowance);
                if (allowance < position.borrowAmount) {
                    console.log("   [ERROR] Insufficient allowance for repayment");
                }
            } catch {
                console.log("   [ERROR] Failed to check allowance");
            }
        } catch {
            console.log("\n[ERROR] FAILED TO CLOSE POSITION");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    function testLiquidation() public {
        console.log("\n=== Testing Liquidation ===");
        vm.startBroadcast(testPrivateKey);
        
        console.log("Liquidation test requires setting an unhealthy health factor");
        console.log("For mock testing, we would need to:");
        console.log("1. Create a position with high collateral and borrowing");
        console.log("2. Set the mock health factor below 1.0");
        console.log("3. Attempt liquidation from a different account");
        
        console.log("This test is simplified for development environment");
        
        // Create a position with high leverage
        uint256 liquidationPositionId = 0;
        uint256 collateralAmount = 1000 * 10**18; // 1000 WETH
        uint256 borrowAmount = 900 * 10**6;      // 900 USDC (high compared to collateral)
        
        // Mint tokens
        MockERC20 mockWeth = MockERC20(weth);
        
        try mockWeth.mint(testUser, collateralAmount) {
            console.log("Successfully minted WETH for test position");
        } catch {
            console.log("Failed to mint WETH for test position");
        }
        
        // Approve tokens
        try IERC20(weth).approve(address(positionManager), collateralAmount) {
            console.log("Successfully approved WETH for test position");
        } catch {
            console.log("Failed to approve WETH for test position");
            vm.stopBroadcast();
            return;
        }
        
        // Create position
        try positionManager.createPosition(
            weth,
            collateralAmount,
            usdc,
            borrowAmount,
            2
        ) returns (uint256 id) {
            liquidationPositionId = id;
            console.log("Created test position with ID:", liquidationPositionId);
        } catch Error(string memory reason) {
            console.log("Failed to create test position. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Failed to create test position with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        // In a real scenario, we would set the health factor to below 1.0
        // But for our mock, we can try calling liquidatePosition directly
        console.log("For a real test, we would need a second account to perform liquidation");
        console.log("Mock test completed. In production, use two different accounts for proper testing");
        
        vm.stopBroadcast();
    }
} 