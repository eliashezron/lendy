// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockERC20Permit} from "../test/mocks/MockERC20Permit.sol";

/**
 * @title InteractLendy
 * @notice Script to interact with deployed Lendy contracts on Celo testnet
 */
contract InteractLendy is Script {
    // Contract addresses from deployment
    address public constant LENDY_PROTOCOL = 0xAe84B9e6dBa48D14f4ec7741666c976C0556A295;
    address public constant LENDY_POSITION_MANAGER = 0xA41cC78C1F302A35184dDBE225d5530376cAd254;
    address public constant USDC = 0x7262Bfada9f61530119693d532E716D5CD3191eC;
    address public constant WETH = 0xAC166A1B90308cA742Db5b388FFCBdc3E17a186c;
    address public constant DAI = 0x3B346548fbfa74623047B1E199a96576dd156f2e; // DAI with permit
    
    // Common variables
    LendyProtocol public lendyProtocol;
    LendyPositionManager public positionManager;
    address public user;
    uint256 public userPrivateKey;
    
    // For permit functionality
    uint256 public deadline;
    uint8 public v = 27; // Mock v
    bytes32 public r = bytes32(uint256(1)); // Mock r
    bytes32 public s = bytes32(uint256(2)); // Mock s

    function setUp() public {
        // Process private key
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            userPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("PRIVATE_KEY");
            if (bytes(pkString).length > 0 && bytes(pkString)[0] == "0" && bytes(pkString)[1] == "x") {
                userPrivateKey = vm.parseUint(pkString);
            } else {
                // If no 0x prefix, try adding it
                userPrivateKey = vm.parseUint(string(abi.encodePacked("0x", pkString)));
            }
        }
        
        user = vm.addr(userPrivateKey);
        lendyProtocol = LendyProtocol(LENDY_PROTOCOL);
        positionManager = LendyPositionManager(LENDY_POSITION_MANAGER);
        deadline = block.timestamp + 1 hours;
    }

    function run() public {
        vm.startBroadcast(userPrivateKey);
        
        console.log("User address:", user);
        
        // Mint tokens first
        mintTokens();
        
        // Basic tests
        testBasicFunctionality();
        
        // Test permit functions
        testPermitFunctions();
        
        // Test position with DAI
        testCreatePosition();
        
        // Test position manager permit functions
        testPositionManagerPermitFunctions();
        
        vm.stopBroadcast();
    }
    
    function mintTokens() internal {
        console.log("\n=== Minting Tokens for Testing ===");
        
        // Mint USDC to user
        uint256 usdcAmount = 10000 * 10**6; // 10,000 USDC
        console.log("Minting USDC...");
        MockERC20(USDC).mint(user, usdcAmount);
        console.log("USDC balance:", IERC20(USDC).balanceOf(user));
        
        // Mint WETH to user
        uint256 wethAmount = 10 * 10**18; // 10 WETH
        console.log("Minting WETH...");
        MockERC20(WETH).mint(user, wethAmount);
        console.log("WETH balance:", IERC20(WETH).balanceOf(user));
        
        // Mint DAI to user and position manager
        uint256 daiAmount = 10000 * 10**18; // 10,000 DAI
        console.log("Minting DAI...");
        MockERC20Permit(DAI).mint(user, daiAmount);
        console.log("DAI balance:", IERC20(DAI).balanceOf(user));
        
        // Mint DAI to position manager to enable transfers
        console.log("Minting DAI to position manager...");
        MockERC20Permit(DAI).mint(LENDY_POSITION_MANAGER, daiAmount);
    }
    
    function testBasicFunctionality() internal {
        console.log("\n=== Testing Basic Functionality ===");
        
        // 1. Approve tokens for Lendy Protocol
        uint256 collateralAmount = 1 * 10**18; // 1 WETH
        uint256 borrowAmount = 100 * 10**6;   // 100 USDC
        
        console.log("Approving WETH for LendyProtocol...");
        IERC20(WETH).approve(LENDY_PROTOCOL, collateralAmount);
        
        // 2. Supply WETH as collateral
        console.log("Supplying WETH as collateral...");
        lendyProtocol.supply(WETH, collateralAmount, user, 0);
        
        // 3. Borrow USDC
        console.log("Borrowing USDC...");
        lendyProtocol.borrow(USDC, borrowAmount, 2, 0, user);
        
        // 4. Check account data
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            ,  // currentLiquidationThreshold
            ,  // ltv
            uint256 healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Total Collateral:", totalCollateralBase);
        console.log("Total Debt:", totalDebtBase);
        console.log("Available Borrows:", availableBorrowsBase);
        console.log("Health Factor:", healthFactor);
    }
    
    function testPermitFunctions() internal {
        console.log("\n=== Testing Permit Functions ===");
        
        uint256 permitAmount = 1000 * 10**18; // 1000 DAI
        
        // Test supplyWithPermit
        console.log("Testing supplyWithPermit...");
        try lendyProtocol.supplyWithPermit(
            DAI,
            permitAmount,
            user,
            0,
            deadline,
            v,
            r,
            s
        ) {
            console.log("supplyWithPermit successful");
        } catch Error(string memory reason) {
            console.log("supplyWithPermit failed:", reason);
        } catch {
            console.log("supplyWithPermit failed with no reason");
        }
        
        // Test repayWithPermit
        console.log("Testing repayWithPermit...");
        try lendyProtocol.repayWithPermit(
            DAI,
            permitAmount / 2, // Repay half
            2, // Variable rate
            user,
            deadline,
            v,
            r,
            s
        ) returns (uint256 repaidAmount) {
            console.log("repayWithPermit successful, amount repaid:", repaidAmount);
        } catch Error(string memory reason) {
            console.log("repayWithPermit failed:", reason);
        } catch {
            console.log("repayWithPermit failed with no reason");
        }
        
    }
    
    function testCreatePosition() internal {
        console.log("\n=== Testing Position Creation and Management ===");
        
        uint256 collateralAmount = 1 * 10**18; // 1 WETH
        uint256 permitAmount = 500 * 10**18; // 500 DAI
        
        // Approve WETH for position manager
        console.log("Approving WETH for position manager...");
        IERC20(WETH).approve(LENDY_POSITION_MANAGER, collateralAmount);
        
        // Create a position
        console.log("Creating a position...");
        try positionManager.createPosition(
            WETH,
            collateralAmount,
            DAI,
            permitAmount / 2,
            2 // Variable rate
        ) returns (uint256 positionId) {
            console.log("Position created with ID:", positionId);
            
            // Get position details
            LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
            console.log("Position Owner:", position.owner);
            console.log("Collateral Amount:", position.collateralAmount);
            console.log("Borrow Amount:", position.borrowAmount);
            
            // Test repaying the position
            testRepayPosition(positionId, permitAmount / 8);
            
            // Test closing the position instead of liquidation
            testClosePosition(positionId);
        } catch Error(string memory reason) {
            console.log("createPosition failed:", reason);
        } catch {
            console.log("createPosition failed with no reason");
        }
    }
    
    function testRepayPosition(uint256 positionId, uint256 repayAmount) internal {
        console.log("\n=== Testing Position Repayment ===");
        
        // Get position details before repayment
        LendyPositionManager.Position memory positionBefore = positionManager.getPositionDetails(positionId);
        console.log("Position before repayment:");
        console.log("Borrow Amount:", positionBefore.borrowAmount);
        
        // Regular repayment
        console.log("Testing standard repayDebt...");
        // Approve DAI for position manager
        IERC20(DAI).approve(LENDY_POSITION_MANAGER, repayAmount);
        
        try positionManager.repayDebt(positionId, repayAmount) {
            console.log("Repayment successful, amount repaid:", repayAmount);
            
            // Get position details after repayment
            LendyPositionManager.Position memory positionAfter = positionManager.getPositionDetails(positionId);
            console.log("Position after repayment:");
            console.log("Borrow Amount:", positionAfter.borrowAmount);
            console.log("Debt reduction:", positionBefore.borrowAmount - positionAfter.borrowAmount);
        } catch Error(string memory reason) {
            console.log("repayDebt failed:", reason);
        } catch {
            console.log("repayDebt failed with no reason");
        }
        
        // Repay using permit functionality
        console.log("\nTesting repayment using repayWithPermit...");
        // In a real-world scenario, we would use EIP-2612 permit signatures here
        try lendyProtocol.repayWithPermit(
            DAI,
            repayAmount,
            positionBefore.interestRateMode,
            address(positionManager),
            deadline,
            v,
            r,
            s
        ) returns (uint256 repaidAmount) {
            console.log("repayWithPermit successful, amount repaid:", repaidAmount);
            
            // Get updated position details
            LendyPositionManager.Position memory positionAfterPermit = positionManager.getPositionDetails(positionId);
            console.log("Position after repayWithPermit:");
            console.log("Borrow Amount:", positionAfterPermit.borrowAmount);
        } catch Error(string memory reason) {
            console.log("repayWithPermit failed:", reason);
        } catch {
            console.log("repayWithPermit failed with no reason");
        }
    }
    
    function testLiquidatePosition(uint256 positionId, uint256 debtToCover) internal {
        console.log("\n=== Testing Position Liquidation ===");
        
        // Get position details before liquidation
        LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
        console.log("Position before liquidation:");
        console.log("Collateral Amount:", position.collateralAmount);
        console.log("Borrow Amount:", position.borrowAmount);
        
        // Approve DAI for liquidation
        console.log("Approving DAI for liquidation...");
        IERC20(DAI).approve(LENDY_POSITION_MANAGER, debtToCover);
        
        // In real scenario, we'd need to make the position unhealthy first
        // For testing purposes, we'll try to liquidate anyway to see the error or success
        console.log("Attempting to liquidate position...");
        try positionManager.liquidatePosition(
            positionId,
            debtToCover,
            false // Don't receive aTokens
        ) returns (uint256 liquidatedCollateralAmount, uint256 debtAmount) {
            console.log("Liquidation successful:");
            console.log("Liquidated Collateral Amount:", liquidatedCollateralAmount);
            console.log("Debt Amount Covered:", debtAmount);
            
            // Get position details after liquidation
            LendyPositionManager.Position memory positionAfter = positionManager.getPositionDetails(positionId);
            console.log("Position after liquidation:");
            console.log("Collateral Amount:", positionAfter.collateralAmount);
            console.log("Borrow Amount:", positionAfter.borrowAmount);
            console.log("Is Active:", positionAfter.active);
        } catch Error(string memory reason) {
            console.log("liquidatePosition failed:", reason);
        } catch {
            console.log("liquidatePosition failed with no reason");
        }
    }
    
    /**
     * @notice Test closing a position by repaying all debt and withdrawing collateral
     * @param positionId The ID of the position to close
     */
    function testClosePosition(uint256 positionId) internal {
        console.log("\n=== Testing Position Closure ===");
        
        // Get position details before closing
        LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
        console.log("Position before closing:");
        console.log("Collateral Amount:", position.collateralAmount);
        console.log("Borrow Amount:", position.borrowAmount);
        console.log("Is Active:", position.active);
        
        // Approve DAI for final repayment
        console.log("Approving DAI for final repayment...");
        IERC20(DAI).approve(LENDY_POSITION_MANAGER, position.borrowAmount);
        
        // Attempt to close the position
        console.log("Attempting to close position...");
        try positionManager.closePosition(positionId) {
            console.log("Position closed successfully");
            
            // Get position details after closing
            LendyPositionManager.Position memory positionAfter = positionManager.getPositionDetails(positionId);
            console.log("Position after closing:");
            console.log("Collateral Amount:", positionAfter.collateralAmount);
            console.log("Borrow Amount:", positionAfter.borrowAmount);
            console.log("Is Active:", positionAfter.active);
            
            // Check WETH balance after position is closed (should have received collateral back)
            uint256 wethBalance = IERC20(WETH).balanceOf(user);
            console.log("WETH balance after position closure:", wethBalance);
        } catch Error(string memory reason) {
            console.log("closePosition failed:", reason);
        } catch {
            console.log("closePosition failed with no reason");
        }
    }

    /**
     * @notice Test the permit functions in LendyPositionManager
     */
    function testPositionManagerPermitFunctions() internal {
        console.log("\n=== Testing Position Manager Permit Functions ===");
        
        uint256 collateralAmount = 1 * 10**18; // 1 WETH
        uint256 permitAmount = 500 * 10**18; // 500 DAI
        uint256 additionalCollateral = 0.5 * 10**18; // 0.5 WETH
        uint256 repayAmount = 100 * 10**18; // 100 DAI
        
        // Create a position first
        console.log("Approving WETH for position manager...");
        IERC20(WETH).approve(LENDY_POSITION_MANAGER, collateralAmount);
        
        console.log("Creating a position...");
        uint256 positionId;
        try positionManager.createPosition(
            WETH,
            collateralAmount,
            DAI,
            permitAmount / 2,
            2 // Variable rate
        ) returns (uint256 id) {
            positionId = id;
            console.log("Position created with ID:", positionId);
            
            // Get initial position details
            LendyPositionManager.Position memory position = positionManager.getPositionDetails(positionId);
            console.log("Initial position state:");
            console.log("Collateral Amount:", position.collateralAmount);
            console.log("Borrow Amount:", position.borrowAmount);
            
            // Test addCollateralWithPermit
            console.log("\nTesting addCollateralWithPermit...");
            try positionManager.addCollateralWithPermit(
                positionId,
                additionalCollateral,
                deadline,
                v,
                r,
                s
            ) {
                console.log("Added collateral with permit successfully");
                
                // Check updated position
                position = positionManager.getPositionDetails(positionId);
                console.log("Position after adding collateral:");
                console.log("Collateral Amount:", position.collateralAmount);
            } catch Error(string memory reason) {
                console.log("addCollateralWithPermit failed:", reason);
            } catch {
                console.log("addCollateralWithPermit failed with no reason");
            }
            
            // Test repayDebtWithPermit
            console.log("\nTesting repayDebtWithPermit...");
            try positionManager.repayDebtWithPermit(
                positionId,
                repayAmount,
                deadline,
                v,
                r,
                s
            ) returns (uint256 repaidAmount) {
                console.log("Repaid debt with permit, amount:", repaidAmount);
                
                // Check updated position
                position = positionManager.getPositionDetails(positionId);
                console.log("Position after repaying debt:");
                console.log("Borrow Amount:", position.borrowAmount);
            } catch Error(string memory reason) {
                console.log("repayDebtWithPermit failed:", reason);
            } catch {
                console.log("repayDebtWithPermit failed with no reason");
            }
            
            // Test closePositionWithPermit
            console.log("\nTesting closePositionWithPermit...");
            // Create another position to close
            IERC20(WETH).approve(LENDY_POSITION_MANAGER, collateralAmount);
            uint256 closePositionId;
            try positionManager.createPosition(
                WETH,
                collateralAmount,
                DAI,
                permitAmount / 4,
                2 // Variable rate
            ) returns (uint256 newId) {
                closePositionId = newId;
                console.log("Created position to close, ID:", closePositionId);
                
                try positionManager.closePositionWithPermit(
                    closePositionId,
                    deadline,
                    v,
                    r,
                    s
                ) {
                    console.log("Closed position with permit successfully");
                    
                    // Check position is closed
                    LendyPositionManager.Position memory closedPosition = positionManager.getPositionDetails(closePositionId);
                    console.log("Position after closing:");
                    console.log("Is Active:", closedPosition.active);
                    console.log("Collateral Amount:", closedPosition.collateralAmount);
                    console.log("Borrow Amount:", closedPosition.borrowAmount);
                } catch Error(string memory reason) {
                    console.log("closePositionWithPermit failed:", reason);
                } catch {
                    console.log("closePositionWithPermit failed with no reason");
                }
            } catch {
                console.log("Failed to create position for closing test");
            }
            
        } catch Error(string memory reason) {
            console.log("createPosition failed:", reason);
        } catch {
            console.log("createPosition failed with no reason");
        }
    }
} 