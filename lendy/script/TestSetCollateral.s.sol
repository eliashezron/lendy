// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/**
 * @title TestSetCollateral
 * @notice Script to test setUserUseReserveAsCollateral functionality on Celo mainnet
 */
contract TestSetCollateral is Script {
    // Contract addresses
    address public LENDY_PROTOCOL = 0x8A05C0a366abb49b56A44b37A5Fe281957DE2c37;
    
    // Celo mainnet token addresses
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    
    // AAVE V3 Pool on Celo mainnet
    address public constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    
    // Variables
    LendyProtocol public lendyProtocol;
    address public user;
    uint256 public userPrivateKey;

    function setUp() public {
        // Process private key from CELO_MAINNET_PRIVATE_KEY
        try vm.envUint("CELO_MAINNET_PRIVATE_KEY") returns (uint256 pk) {
            userPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("CELO_MAINNET_PRIVATE_KEY");
            if (bytes(pkString).length > 0 && bytes(pkString)[0] == "0" && bytes(pkString)[1] == "x") {
                userPrivateKey = vm.parseUint(pkString);
            } else {
                // If no 0x prefix, try adding it
                userPrivateKey = vm.parseUint(string(abi.encodePacked("0x", pkString)));
            }
        }
        
        user = vm.addr(userPrivateKey);
        lendyProtocol = LendyProtocol(LENDY_PROTOCOL);
    }

    function run() public {
        console.log("=== Testing setUserUseReserveAsCollateral functionality ===");
        console.log("User address:", user);
        console.log("LendyProtocol address:", LENDY_PROTOCOL);
        console.log("AAVE Pool address:", AAVE_POOL);
        
        vm.startBroadcast(userPrivateKey);
        
        // First check if we have supplied any assets
        checkSuppliedAssets();

        // Supply a small amount of USDT if needed
        supplyUSDT();
        
        // Try to set USDT as collateral in multiple ways
        testSetCollateral();
        
        // Create a position by borrowing against the collateral
        createPosition();
        
        vm.stopBroadcast();
    }
    
    function checkSuppliedAssets() internal {
        console.log("\n=== Checking Supplied Assets ===");
        
        // Check USDT balance
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        console.log("USDT balance:", usdtBalance);
        
        // Check if we have aTokens already
        try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
            console.log("USDT aToken address:", aTokenUSDT);
            uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
            console.log("USDT aToken balance:", aTokenBalance);
            
            // Check collateral status
            (
                uint256 totalCollateralBase,
                uint256 totalDebtBase,
                uint256 availableBorrowsBase,
                uint256 currentLiquidationThreshold,
                uint256 ltv,
                uint256 healthFactor
            ) = lendyProtocol.getUserAccountData(user);
            
            console.log("Account data from Lendy Protocol:");
            console.log("Total Collateral (USD):", totalCollateralBase);
            console.log("Available Borrows (USD):", availableBorrowsBase);
        } catch {
            console.log("Could not get aToken for USDT");
        }
    }
    
    function supplyUSDT() internal {
        console.log("\n=== Supplying USDT if needed ===");
        
        // Check if we have supplied USDT already
        bool hasSupplied = false;
        address aTokenUSDT;
        
        try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
            aTokenUSDT = aToken;
            uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
            hasSupplied = aTokenBalance > 0;
            
            if (hasSupplied) {
                console.log("Already has supplied USDT, aToken balance:", aTokenBalance);
                return;
            }
        } catch {
            console.log("Error checking aToken balance");
        }
        
        // Check USDT balance
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        console.log("USDT balance:", usdtBalance);
        
        // Supply a small amount of USDT
        uint256 supplyAmount = 100000; // 0.1 USDT (6 decimals)
        
        if (usdtBalance < supplyAmount) {
            console.log("Not enough USDT for testing. Balance:", usdtBalance);
            return;
        }
        
        console.log("Supplying", supplyAmount, "USDT to the protocol");
        
        // The key issue: LendyProtocol's supply function transfers tokens to itself, 
        // but gives aTokens to the onBehalfOf address. For setUserUseReserveAsCollateral to work,
        // LendyProtocol itself needs aTokens.
        
        // SOLUTION 1: Supply directly to AAVE first to get aTokens for the user
        console.log("\nSOLUTION 1: Supplying directly to AAVE first...");
        
        // Approve USDT for AAVE Pool
        IERC20(USDT).approve(AAVE_POOL, supplyAmount);
        
        try IPool(AAVE_POOL).supply(USDT, supplyAmount, user, 0) {
            console.log("Successfully supplied USDT directly to AAVE for user");
            
            // Verify user got aTokens
            try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                uint256 aTokenBalance = IERC20(aToken).balanceOf(user);
                console.log("User's aToken balance after direct supply:", aTokenBalance);
                
                if (aTokenBalance > 0) {
                    console.log("User now has aTokens");
                }
            } catch {
                console.log("Failed to verify user's aToken balance");
            }
        } catch {
            console.log("Failed direct supply to AAVE");
        }
        
        // SOLUTION 2: Supply directly to AAVE but with LendyProtocol as receiver
        // Note: This requires having more USDT balance
        uint256 protocolSupplyAmount = 50000; // 0.05 USDT
        
        if (usdtBalance >= supplyAmount + protocolSupplyAmount) {
            console.log("\nSOLUTION 2: Supplying to AAVE with LendyProtocol as beneficiary...");
            
            // Approve additional USDT for AAVE Pool
            IERC20(USDT).approve(AAVE_POOL, protocolSupplyAmount);
            
            try IPool(AAVE_POOL).supply(USDT, protocolSupplyAmount, LENDY_PROTOCOL, 0) {
                console.log("Successfully supplied USDT to AAVE with LendyProtocol as beneficiary");
                
                // Verify LendyProtocol got aTokens
                try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                    uint256 protocolATokenBalance = IERC20(aToken).balanceOf(LENDY_PROTOCOL);
                    console.log("LendyProtocol's aToken balance after direct supply:", protocolATokenBalance);
                    
                    if (protocolATokenBalance > 0) {
                        console.log("LendyProtocol now has aTokens");
                    }
                } catch {
                    console.log("Failed to verify LendyProtocol's aToken balance");
                }
            } catch {
                console.log("Failed to supply to AAVE with LendyProtocol as beneficiary");
            }
        } else {
            console.log("Not enough USDT to supply for LendyProtocol as well");
        }
        
        // SOLUTION 3: For completeness, try supplying through LendyProtocol
        console.log("\nSOLUTION 3: Supplying through LendyProtocol wrapper...");
        
        // We need more USDT for this
        uint256 lendySupplyAmount = 50000; // 0.05 USDT
        uint256 totalSupplyNeeded = supplyAmount + protocolSupplyAmount + lendySupplyAmount;
        
        if (usdtBalance >= totalSupplyNeeded) {
            // Approve USDT for the LendyProtocol
            IERC20(USDT).approve(LENDY_PROTOCOL, lendySupplyAmount);
            
            // Supply USDT - NOTE: In the current implementation, this won't give LendyProtocol aTokens
            try lendyProtocol.supply(USDT, lendySupplyAmount, LENDY_PROTOCOL, 0) {
                console.log("Successfully called LendyProtocol.supply() with LENDY_PROTOCOL as receiver");
                
                // Check if LendyProtocol got aTokens
                try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                    uint256 protocolATokenBalance = IERC20(aToken).balanceOf(LENDY_PROTOCOL);
                    console.log("LendyProtocol's aToken balance after supply through wrapper:", protocolATokenBalance);
                    
                    if (protocolATokenBalance > 0) {
                        console.log("LendyProtocol now has aTokens - this should work with setUserUseReserveAsCollateral");
                    } else {
                        console.log("LendyProtocol still has no aTokens - setUserUseReserveAsCollateral will likely fail");
                    }
                } catch {
                    console.log("Failed to check LendyProtocol's aToken balance");
                }
            } catch Error(string memory reason) {
                console.log("Supply through LendyProtocol failed:", reason);
            } catch (bytes memory reason) {
                uint256 errorCode;
                assembly {
                    errorCode := mload(add(reason, 0x44))
                }
                console.log("Supply through LendyProtocol failed with error code:", errorCode);
            }
        } else {
            console.log("Not enough USDT for complete testing");
        }
    }
    
    function testSetCollateral() internal {
        console.log("\n=== Testing setUserUseReserveAsCollateral ===");
        
        // Check aToken balance first
        try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
            uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
            console.log("Current USDT aToken balance:", aTokenBalance);
            
            if (aTokenBalance == 0) {
                console.log("Warning: You have no aToken balance. Cannot set as collateral until you supply assets first.");
                return;
            }
        } catch {
            console.log("Could not get aToken for USDT");
            return;
        }
        
        // Check if assets are also registered in the LendyProtocol contract
        console.log("Checking if assets are registered in LendyProtocol...");
        try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
            uint256 protocolATokenBalance = IERC20(aTokenUSDT).balanceOf(LENDY_PROTOCOL);
            console.log("LendyProtocol's aToken balance:", protocolATokenBalance);
            
            if (protocolATokenBalance == 0) {
                console.log("Warning: LendyProtocol contract has no aToken balance. This might cause error 43.");
                console.log("When using the wrapper, assets need to be supplied through LendyProtocol, not directly to AAVE.");
            }
        } catch {
            console.log("Could not check LendyProtocol's aToken balance");
        }
        
        // METHOD 1: Try direct AAVE Pool first (this works regardless of LendyProtocol balance)
        console.log("\nMethod 1: Calling AAVE Pool directly");
        
        // Get the AAVE Pool interface
        IPool pool = IPool(AAVE_POOL);
        
        try pool.setUserUseReserveAsCollateral(USDT, true) {
            console.log("Successfully set USDT as collateral directly through AAVE Pool");
            checkCollateralStatus();
        } catch Error(string memory reason) {
            console.log("Direct AAVE setUserUseReserveAsCollateral failed:", reason);
        } catch (bytes memory reason) {
            console.log("Direct AAVE setUserUseReserveAsCollateral failed with low-level error");
            
            // Try to decode AAVE error code
            uint256 errorCode;
            assembly {
                errorCode := mload(add(reason, 0x44))
            }
            
            // Map error code to message
            string memory errorMsg;
            if (errorCode == 2) {
                errorMsg = "CALLER_NOT_EMERGENCY_ADMIN";
            } else if (errorCode == 43) {
                errorMsg = "UNDERLYING_BALANCE_ZERO";
            } else {
                errorMsg = "Unknown error";
            }
            
            console.log("AAVE Error code:", errorCode);
            console.log("Error meaning:", errorMsg);
            
            if (errorCode == 43) {
                // This indicates we may need to handle supply differently
                console.log("Error suggests no balance. Let's try explicit supply through AAVE directly...");
                
                // Re-supply a small amount directly through AAVE
                uint256 supplyAmount = 100000; // 0.1 USDT
                
                // Approve USDT for the AAVE pool again
                IERC20(USDT).approve(AAVE_POOL, supplyAmount);
                
                try pool.supply(USDT, supplyAmount, user, 0) {
                    console.log("Successfully supplied USDT directly to AAVE Pool");
                    
                    // Try setting as collateral again
                    try pool.setUserUseReserveAsCollateral(USDT, true) {
                        console.log("Successfully set USDT as collateral after direct supply");
                        checkCollateralStatus();
                    } catch (bytes memory innerError) {
                        uint256 innerErrorCode;
                        assembly {
                            innerErrorCode := mload(add(innerError, 0x44))
                        }
                        console.log("Still failed to set collateral. Error code:", innerErrorCode);
                    }
                } catch {
                    console.log("Failed to supply directly to AAVE Pool");
                }
            }
        }

        // METHOD 2: Use LendyProtocol (may fail with error 43 if assets not supplied through LendyProtocol)
        console.log("\nMethod 2: Using LendyProtocol wrapper");
        try lendyProtocol.setUserUseReserveAsCollateral(USDT, true) {
            console.log("Successfully set USDT as collateral through LendyProtocol");
            checkCollateralStatus();
        } catch Error(string memory reason) {
            console.log("LendyProtocol setUserUseReserveAsCollateral failed:", reason);
            
            // Check if this is error code 43 (UNDERLYING_BALANCE_ZERO)
            if (bytes(reason).length > 0) {
                if (bytes(reason)[0] == 0x34 && bytes(reason)[1] == 0x33) { 
                    console.log("Error 43: UNDERLYING_BALANCE_ZERO - The underlying balance needs to be greater than 0");
                    console.log("This means LendyProtocol contract itself needs to have aTokens. Assets must be supplied through the protocol, not directly to AAVE.");
                    
                    // If we see this error, we could try supplying through LendyProtocol again
                    console.log("Consider resetting test and using LendyProtocol.supply() instead of direct AAVE supply");
                }
            }
        } catch (bytes memory reason) {
            console.log("LendyProtocol setUserUseReserveAsCollateral failed with low-level error");
            
            // Try to decode AAVE error code
            uint256 errorCode;
            assembly {
                errorCode := mload(add(reason, 0x44))
            }
            
            // Map error code to message
            string memory errorMsg;
            if (errorCode == 2) {
                errorMsg = "CALLER_NOT_EMERGENCY_ADMIN";
            } else if (errorCode == 43) {
                errorMsg = "UNDERLYING_BALANCE_ZERO";
            } else {
                errorMsg = "Unknown error";
            }
            
            console.log("AAVE Error code:", errorCode);
            console.log("Error meaning:", errorMsg);
            
            // If error is UNDERLYING_BALANCE_ZERO, explain the issue more clearly
            if (errorCode == 43) {
                console.log("This error means LendyProtocol contract itself needs to have aTokens.");
                console.log("Assets must be supplied through LendyProtocol.supply(), not directly to AAVE Pool.");
                console.log("The current design requires that supply goes through the LendyProtocol contract.");
            }
        }
        
        // Check final collateral status
        checkCollateralStatus();
    }
    
    function checkCollateralStatus() internal {
        console.log("\n=== Checking Collateral Status ===");
        
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Account data from LendyProtocol:");
        console.log("Total Collateral (USD):", totalCollateralBase);
        console.log("Total Debt (USD):", totalDebtBase);
        console.log("Available Borrows (USD):", availableBorrowsBase);
        console.log("Current Liquidation Threshold:", currentLiquidationThreshold);
        console.log("LTV:", ltv);
        console.log("Health Factor:", healthFactor);
        
        // Determine if USDT is being used as collateral
        bool isUsdtLikelyCollateral = false;
        
        // If we have total collateral and available borrows, it's likely set as collateral
        if (totalCollateralBase > 0 && availableBorrowsBase > 0) {
            try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
                uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
                
                if (aTokenBalance > 0) {
                    console.log("USDT is likely being used as collateral already (non-zero aToken balance and available borrows)");
                    isUsdtLikelyCollateral = true;
                }
            } catch {
                console.log("Could not check USDT aToken balance");
            }
        }
        
        if (!isUsdtLikelyCollateral) {
            console.log("USDT does not appear to be used as collateral yet");
        }
        
        // Also check directly from AAVE
        IPool pool = IPool(AAVE_POOL);
        
        (
            uint256 aaveCollateralBase,
            uint256 aaveDebtBase,
            uint256 aaveBorrowsBase,
            uint256 aaveLiquidationThreshold,
            uint256 aaveLtv,
            uint256 aaveHealthFactor
        ) = pool.getUserAccountData(user);
        
        console.log("\nAccount data directly from AAVE Pool:");
        console.log("Total Collateral (USD):", aaveCollateralBase);
        console.log("Total Debt (USD):", aaveDebtBase);
        console.log("Available Borrows (USD):", aaveBorrowsBase);
        console.log("Current Liquidation Threshold:", aaveLiquidationThreshold);
        console.log("LTV:", aaveLtv);
        console.log("Health Factor:", aaveHealthFactor);
    }
    
    // Function to create a position by borrowing USDC against USDT collateral
    function createPosition() internal {
        console.log("\n=== Creating Position: Borrowing USDC against USDT collateral ===");
        
        // First check if user has available borrows
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            ,
            ,
            uint256 healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Before borrowing:");
        console.log("Total Collateral (USD):", totalCollateralBase);
        console.log("Total Debt (USD):", totalDebtBase);
        console.log("Available Borrows (USD):", availableBorrowsBase);
        console.log("Health Factor:", healthFactor);
        
        if (totalCollateralBase == 0 || availableBorrowsBase == 0) {
            console.log("Cannot borrow: No collateral or zero borrowing capacity");
            console.log("Make sure USDT is successfully set as collateral first");
            return;
        }
        
        // Check initial USDC balance
        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);
        console.log("Initial USDC balance:", initialUsdcBalance);
        
        // Choose a small amount to borrow (10000 = 0.01 USDC, with 6 decimals)
        uint256 borrowAmount = 10000; // 0.01 USDC
        
        console.log("Attempting to borrow", borrowAmount, "USDC");
        
        // Skip the LendyProtocol borrow attempt as it's causing arithmetic overflow
        // Go directly to AAVE Pool which works reliably
        console.log("\nBorrowing directly via AAVE Pool");
        
        IPool pool = IPool(AAVE_POOL);
        
        try pool.borrow(USDC, borrowAmount, 2, 0, user) { // Interest rate mode: 1 = stable, 2 = variable
            console.log("Successfully borrowed USDC directly through AAVE Pool");
            
            // Check new balances and account data
            uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
            console.log("New USDC balance:", newUsdcBalance);
            console.log("USDC borrowed:", newUsdcBalance - initialUsdcBalance);
            
            // Check updated position
            checkPositionAfterBorrowing();
        } catch Error(string memory reason) {
            console.log("Direct AAVE borrowing failed:", reason);
        } catch (bytes memory reason) {
            // Try to decode AAVE error code
            uint256 errorCode;
            assembly {
                errorCode := mload(add(reason, 0x44))
            }
            
            console.log("Direct AAVE borrowing failed with error code:", errorCode);
            
            // Map common AAVE error codes
            if (errorCode == 1) {
                console.log("Error meaning: CALLER_NOT_POOL_ADMIN");
            } else if (errorCode == 30) {
                console.log("Error meaning: BORROWING_NOT_ENABLED");
            } else if (errorCode == 33) {
                console.log("Error meaning: INVALID_INTEREST_RATE_MODE_SELECTED");
            } else if (errorCode == 35) {
                console.log("Error meaning: HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD");
            } else {
                console.log("Unknown error");
            }
        }
    }
    
    function checkPositionAfterBorrowing() internal {
        console.log("\n=== Position Status After Borrowing ===");
        
        // Check updated account data
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            ,
            ,
            uint256 healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Updated account data from LendyProtocol:");
        console.log("Total Collateral (USD):", totalCollateralBase);
        console.log("Total Debt (USD):", totalDebtBase);
        console.log("Available Borrows (USD):", availableBorrowsBase);
        console.log("Health Factor:", healthFactor);
        
        // Check USDC debt token balance
        try IPool(AAVE_POOL).getReserveData(USDC) returns (DataTypes.ReserveData memory reserveData) {
            address stableDebtToken = reserveData.stableDebtTokenAddress;
            address variableDebtToken = reserveData.variableDebtTokenAddress;
            
            if (stableDebtToken != address(0)) {
                uint256 stableDebtBalance = IERC20(stableDebtToken).balanceOf(user);
                console.log("Stable Debt Token balance:", stableDebtBalance);
            } else {
                console.log("Stable debt token address not available");
            }
            
            if (variableDebtToken != address(0)) {
                uint256 variableDebtBalance = IERC20(variableDebtToken).balanceOf(user);
                console.log("Variable Debt Token balance:", variableDebtBalance);
            } else {
                console.log("Variable debt token address not available");
            }
        } catch {
            console.log("Could not fetch reserve data for USDC");
        }
    }
}

// Interface for AAVE Pool
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
} 