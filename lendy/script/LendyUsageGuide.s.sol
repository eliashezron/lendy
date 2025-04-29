// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LendyUsageGuide
 * @notice Guide script showing the correct way to use Lendy Protocol with small amounts
 *
 * IMPORTANT NOTES:
 * 
 * 1. The Lendy Protocol works by interacting with AAVE V3 on Celo. Some operations,
 *    specifically setting tokens as collateral through the Position Manager, 
 *    may fail with AAVE error code 43 ("NOT_ENOUGH_AVAILABLE_USER_BALANCE").
 * 
 * 2. To work around this issue:
 *    - Use small amounts (0.1 USDT for supply, 0.01 USDC for borrow)
 *    - Use direct borrows through the protocol instead of creating positions
 *    - If needed, try interacting with AAVE directly using the TEST_FUNCTION=direct option
 * 
 * 3. When using the deploy.sh script, try these commands:
 *    - ./deploy.sh celo_mainnet interact supply
 *    - ./deploy.sh celo_mainnet interact borrow 
 *    - ./deploy.sh celo_mainnet interact direct
 * 
 * 4. Recommended AAVE Pool Address: 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402
 */
contract LendyUsageGuide is Script {
    // Contract addresses
    address public constant LENDY_PROTOCOL = 0x80A076F99963C3399F12FE114507b54c13f28510;
    address public constant LENDY_POSITION_MANAGER = 0x5a34479FfcAAB729071725515773E68742d43672;
    
    // Celo mainnet token addresses
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    
    // Contract instances
    LendyProtocol public lendyProtocol;
    LendyPositionManager public positionManager;
    address public user;
    
    // Test amounts
    uint256 public constant SUPPLY_AMOUNT = 100000; // 0.1 USDT
    uint256 public constant BORROW_AMOUNT = 10000;  // 0.01 USDC
    
    function setUp() public {}

    function run() public {
        user = msg.sender;
        lendyProtocol = LendyProtocol(LENDY_PROTOCOL);
        positionManager = LendyPositionManager(LENDY_POSITION_MANAGER);
        
        console.log("=== Lendy Protocol Usage Guide ===");
        console.log("User address:", user);
        
        vm.startBroadcast();
        
        // Check balances
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        uint256 usdcBalance = IERC20(USDC).balanceOf(user);
        
        console.log("\n--- Initial Balances ---");
        console.log("USDT balance:", usdtBalance);
        console.log("USDC balance:", usdcBalance);
        
        if (usdtBalance < SUPPLY_AMOUNT) {
            console.log("Not enough USDT. Need at least 0.1 USDT");
            vm.stopBroadcast();
            return;
        }
        
        // 1. Direct Supply Method
        console.log("\n--- Method 1: Direct Supply and Borrow ---");
        directSupplyAndBorrow();
        
        // 2. Position Manager Method
        console.log("\n--- Method 2: Using Position Manager ---");
        usePositionManager();
        
        vm.stopBroadcast();
        console.log("\n=== End of Guide ===");
    }
    
    function directSupplyAndBorrow() internal {
        console.log("Step 1: Approve USDT for LendyProtocol");
        IERC20(USDT).approve(LENDY_PROTOCOL, SUPPLY_AMOUNT);
        
        console.log("Step 2: Supply USDT through LendyProtocol");
        try lendyProtocol.supply(USDT, SUPPLY_AMOUNT, user, 0) {
            console.log("Supply successful!");
            
            // Check if we have aTokens
            address aTokenUSDT;
            try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                aTokenUSDT = aToken;
                uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
                console.log("aToken balance:", aTokenBalance);
                
                // Check account data
                (
                    uint256 totalCollateralBase,
                    uint256 totalDebtBase,
                    uint256 availableBorrowsBase,
                    uint256 currentLiquidationThreshold,
                    uint256 ltv,
                    uint256 healthFactor
                ) = lendyProtocol.getUserAccountData(user);
                
                console.log("Account data:");
                console.log("Total Collateral (USD):", totalCollateralBase);
                console.log("Available Borrows (USD):", availableBorrowsBase);
                console.log("Health Factor:", healthFactor);
                
                // Step 3: Borrow USDC
                console.log("Step 3: Borrow USDC directly");
                try lendyProtocol.borrow(USDC, BORROW_AMOUNT, 2, 0, user) {
                    console.log("Borrow successful!");
                    
                    // Check new USDC balance
                    uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
                    console.log("New USDC balance:", newUsdcBalance);
                    
                    // Check updated account data
                    (
                        uint256 updatedCollateralBase,
                        uint256 updatedDebtBase,
                        uint256 updatedBorrowsBase,
                        ,
                        ,
                        uint256 updatedHealthFactor
                    ) = lendyProtocol.getUserAccountData(user);
                    
                    console.log("Updated account data:");
                    console.log("Total Collateral (USD):", updatedCollateralBase);
                    console.log("Total Debt (USD):", updatedDebtBase);
                    console.log("Available Borrows (USD):", updatedBorrowsBase);
                    console.log("Health Factor:", updatedHealthFactor);
                    
                    // Step 4: Repay part of the borrow
                    console.log("Step 4: Repay part of the borrowed USDC");
                    uint256 repayAmount = BORROW_AMOUNT / 2; // Repay half
                    IERC20(USDC).approve(LENDY_PROTOCOL, repayAmount);
                    
                    try lendyProtocol.repay(USDC, repayAmount, 2, user) returns (uint256 actualRepayAmount) {
                        console.log("Repay successful! Amount repaid:", actualRepayAmount);
                        
                        // Check final account data
                        (
                            uint256 finalCollateralBase,
                            uint256 finalDebtBase,
                            uint256 finalBorrowsBase,
                            ,
                            ,
                            uint256 finalHealthFactor
                        ) = lendyProtocol.getUserAccountData(user);
                        
                        console.log("Final account data:");
                        console.log("Total Debt (USD):", finalDebtBase);
                        console.log("Available Borrows (USD):", finalBorrowsBase);
                        console.log("Health Factor:", finalHealthFactor);
                    } catch {
                        console.log("Repay failed");
                    }
                } catch {
                    console.log("Borrow failed");
                }
            } catch {
                console.log("Could not get aToken address");
            }
        } catch {
            console.log("Supply failed");
        }
    }
    
    function usePositionManager() internal {
        console.log("Step 1: Approve USDT for Position Manager");
        IERC20(USDT).approve(LENDY_POSITION_MANAGER, SUPPLY_AMOUNT);
        
        console.log("Step 2: Create a position");
        try positionManager.createPosition(
            USDT,
            SUPPLY_AMOUNT,
            USDC,
            BORROW_AMOUNT,
            2 // Variable interest rate
        ) returns (uint256 positionId) {
            console.log("Position created successfully! ID:", positionId);
            
            // Get position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
                console.log("Position details:");
                console.log("Collateral Asset:", position.collateralAsset);
                console.log("Collateral Amount:", position.collateralAmount);
                console.log("Borrow Asset:", position.borrowAsset);
                console.log("Borrow Amount:", position.borrowAmount);
                console.log("Active:", position.active);
                
                // Check account data
                (
                    uint256 totalCollateralBase,
                    uint256 totalDebtBase,
                    uint256 availableBorrowsBase,
                    ,
                    ,
                    uint256 healthFactor
                ) = lendyProtocol.getUserAccountData(user);
                
                console.log("Account data after position creation:");
                console.log("Total Collateral (USD):", totalCollateralBase);
                console.log("Total Debt (USD):", totalDebtBase);
                console.log("Available Borrows (USD):", availableBorrowsBase);
                console.log("Health Factor:", healthFactor);
                
                // Step 3: Repay part of the position
                console.log("Step 3: Repay part of the position");
                uint256 repayAmount = BORROW_AMOUNT / 2; // Repay half
                IERC20(USDC).approve(LENDY_POSITION_MANAGER, repayAmount);
                
                try positionManager.repayDebt(positionId, repayAmount) {
                    console.log("Position partially repaid successfully!");
                    
                    // Get updated position details
                    try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory updatedPosition) {
                        console.log("Updated position details:");
                        console.log("Borrow Amount:", updatedPosition.borrowAmount);
                        console.log("(Reduced by approximately half)");
                    } catch {
                        console.log("Failed to get updated position details");
                    }
                } catch {
                    console.log("Position repayment failed");
                }
            } catch {
                console.log("Failed to get position details");
            }
        } catch {
            console.log("Failed to create position");
            console.log("Note: If using Position Manager fails, try the direct method above");
        }
    }
} 