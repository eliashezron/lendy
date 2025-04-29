// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";

/**
 * @title InteractCeloMainnet
 * @notice Script to interact with Lendy Protocol on Celo mainnet, handling supply, collateral, borrow, and repay
 * @dev Uses LendyProtocol wrapper and LendyPositionManager instead of direct Aave Pool interaction
 */
contract InteractCeloMainnet is Script {
    // Contract addresses
    address public LENDY_PROTOCOL = 0x8A05C0a366abb49b56A44b37A5Fe281957DE2c37;
    address public LENDY_POSITION_MANAGER =0xEB1CA1B5e9a1396dD5Fdd58Fe27e0C64ba6905Af;
    
    // Celo mainnet token addresses
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    
    // AAVE V3 Pool on Celo mainnet (for reference only)
    address public constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    
    // Variables
    LendyProtocol public lendyProtocol;
    LendyPositionManager public positionManager;
    address public user;
    uint256 public userPrivateKey;
    
    // Test function to run from env
    string public testFunction;
    
    // Common variables for user account data
    uint256 public totalCollateralBase;
    uint256 public totalDebtBase;
    uint256 public availableBorrowsBase;
    uint256 public healthFactor;
    
    // Position ID for tracking
    uint256 public currentPositionId;

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
        
        // Try to get Position Manager address from environment or use hardcoded address
        try vm.envAddress("LENDY_POSITION_MANAGER") returns (address posManager) {
            LENDY_POSITION_MANAGER = posManager;
        } catch {
            // Use a default or hardcoded address if not provided
            // This address should be updated with the actual deployment
            LENDY_POSITION_MANAGER = 0xA41cC78C1F302A35184dDBE225d5530376cAd254;
        }
        positionManager = LendyPositionManager(LENDY_POSITION_MANAGER);
        
        // Get the test function to run from environment variable, default to "all"
        try vm.envString("TEST_FUNCTION") returns (string memory tf) {
            if (bytes(tf).length > 0) {
                testFunction = tf;
            } else {
                testFunction = "all";
            }
        } catch {
            testFunction = "all";
        }
    }

    function run() public {
        console.log("=== Interacting with Lendy Protocol on Celo mainnet ===");
        console.log("User address:", user);
        console.log("LendyProtocol address:", LENDY_PROTOCOL);
        console.log("LendyPositionManager address:", LENDY_POSITION_MANAGER);
        console.log("Selected test function:", testFunction);
        
        vm.startBroadcast(userPrivateKey);
        
        // Check balances and collateral status
        checkBalancesAndStatus();
        
        // Run specific test based on the testFunction variable
        if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("supply"))) {
            supplyUSDT();
        } 
        else if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("collateral"))) {
            setCollateral();
        }
        else if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("borrow"))) {
            borrowUSDC();
        }
        else if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("repay"))) {
            repayUSDC();
        }
        else if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("position"))) {
            createPosition();
        }
        else if (keccak256(abi.encodePacked(testFunction)) == keccak256(abi.encodePacked("all"))) {
            // Run all operations in sequence
            supplyUSDT();
            setCollateral();
            borrowUSDC();
            repayUSDC();
            createPosition();
        }
        else {
            console.log("Unknown test function. Available options: supply, collateral, borrow, repay, position, all");
        }
        
        // Check final status
        checkBalancesAndStatus();
        
        vm.stopBroadcast();
    }
    
    function checkBalancesAndStatus() internal {
        console.log("\n=== Current Balances and Status ===");
        
        // Check token balances
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        uint256 usdcBalance = IERC20(USDC).balanceOf(user);
        uint256 cusdBalance = IERC20(CUSD).balanceOf(user);
        
        console.log("USDT balance:", usdtBalance);
        console.log("USDC balance:", usdcBalance);
        console.log("cUSD balance:", cusdBalance);
        
        // Check if we have aTokens
        try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
            console.log("USDT aToken address:", aTokenUSDT);
            console.log("USDT aToken balance:", IERC20(aTokenUSDT).balanceOf(user));
        } catch {
            console.log("Could not get aToken for USDT");
        }
        
        // Check user account data from LendyProtocol
        try lendyProtocol.getUserAccountData(user) returns (
            uint256 _totalCollateralBase,
            uint256 _totalDebtBase,
            uint256 _availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 _healthFactor
        ) {
            totalCollateralBase = _totalCollateralBase;
            totalDebtBase = _totalDebtBase;
            availableBorrowsBase = _availableBorrowsBase;
            healthFactor = _healthFactor;
            
            console.log("\nAccount data from LendyProtocol:");
            console.log("Total Collateral (USD):", totalCollateralBase);
            console.log("Total Debt (USD):", totalDebtBase);
            console.log("Available Borrows (USD):", availableBorrowsBase);
            console.log("Current Liquidation Threshold:", currentLiquidationThreshold);
            console.log("LTV:", ltv);
            console.log("Health Factor:", healthFactor);
        } catch {
            console.log("Failed to get user account data from LendyProtocol");
        }
        
        // Check for active positions in PositionManager (only if we have a valid currentPositionId)
        if (currentPositionId > 0) {
            try positionManager.getPositionDetails(currentPositionId) returns (LendyPositionManager.Position memory position) {
                console.log("\nPosition", currentPositionId, "details:");
                console.log("  Collateral Asset:", position.collateralAsset);
                console.log("  Collateral Amount:", position.collateralAmount);
                console.log("  Borrow Asset:", position.borrowAsset);
                console.log("  Borrow Amount:", position.borrowAmount);
                console.log("  Interest Rate Mode:", position.interestRateMode);
                console.log("  Active:", position.active);
            } catch {
                console.log("\nFailed to get position details for ID:", currentPositionId);
            }
        } else {
            console.log("\nNo active position created yet");
        }
    }
    
    function supplyUSDT() internal {
        console.log("\n=== Supplying USDT ===");
        
        // Check USDT balance
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        console.log("Current USDT balance:", usdtBalance);
        
        // Supply a small amount of USDT
        uint256 supplyAmount = 100000; // 0.1 USDT (6 decimals)
        
        if (usdtBalance < supplyAmount) {
            console.log("Not enough USDT for testing. Need at least 0.1 USDT.");
            return;
        }
        
        bool supplySuccess = false;
        
        // Method 1: Try supplying through LendyProtocol
        console.log("\nMethod 1: Supplying", supplyAmount, "USDT (0.1 USDT) through LendyProtocol");
        
        // Approve USDT for LendyProtocol
        IERC20(USDT).approve(LENDY_PROTOCOL, supplyAmount);
        
        try lendyProtocol.supply(USDT, supplyAmount, user, 0) {
            console.log("Successfully supplied USDT through LendyProtocol");
            supplySuccess = true;
            
            // Verify user received aTokens
            try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                uint256 aTokenBalance = IERC20(aToken).balanceOf(user);
                console.log("User's aToken balance after supply:", aTokenBalance);
            } catch {
                console.log("Failed to verify aToken balance");
            }
        } catch Error(string memory reason) {
            console.log("Supply through LendyProtocol failed:", reason);
        } catch (bytes memory reason) {
            uint256 errorCode = _extractErrorCode(reason);
            console.log("Supply failed with error code:", errorCode);
            _decodeAaveError(errorCode);
        }
        
        // Method 2: If LendyProtocol supply fails, try direct AAVE Pool
        if (!supplySuccess) {
            console.log("\nMethod 2: Supplying directly to AAVE Pool");
            
            // Approve USDT for AAVE Pool
            IERC20(USDT).approve(AAVE_POOL, supplyAmount);
            
            // Get the AAVE Pool interface
            IPool pool = IPool(AAVE_POOL);
            
            try pool.supply(USDT, supplyAmount, user, 0) {
                console.log("Successfully supplied USDT directly to AAVE Pool");
                supplySuccess = true;
                
                // Verify user received aTokens
                try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                    uint256 aTokenBalance = IERC20(aToken).balanceOf(user);
                    console.log("User's aToken balance after direct supply:", aTokenBalance);
                } catch {
                    console.log("Failed to verify aToken balance");
                }
            } catch Error(string memory reason) {
                console.log("Direct AAVE supply failed:", reason);
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Direct AAVE supply failed with error code:", errorCode);
                _decodeAaveError(errorCode);
            }
        }
        
        // Method 3: Also try supplying some to the LendyProtocol contract itself
        // This can help with the error 43 when setting collateral later
        if (supplySuccess && usdtBalance >= supplyAmount * 2) {
            console.log("\nMethod 3: Supplying to AAVE with LendyProtocol as beneficiary");
            
            uint256 protocolSupplyAmount = 20000; // 0.02 USDT
            
            // Approve USDT for AAVE Pool
            IERC20(USDT).approve(AAVE_POOL, protocolSupplyAmount);
            
            // Get the AAVE Pool interface
            IPool pool = IPool(AAVE_POOL);
            
            try pool.supply(USDT, protocolSupplyAmount, LENDY_PROTOCOL, 0) {
                console.log("Successfully supplied USDT to AAVE with LendyProtocol as beneficiary");
                
                // Verify LendyProtocol got aTokens
                try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
                    uint256 protocolATokenBalance = IERC20(aToken).balanceOf(LENDY_PROTOCOL);
                    console.log("LendyProtocol's aToken balance:", protocolATokenBalance);
                    
                    if (protocolATokenBalance > 0) {
                        console.log("LendyProtocol now has aTokens - this should help with setUserUseReserveAsCollateral");
                    }
                } catch {
                    console.log("Failed to verify LendyProtocol's aToken balance");
                }
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Failed to supply for LendyProtocol with error code:", errorCode);
                _decodeAaveError(errorCode);
            }
        }
        
        // Check final status
        try lendyProtocol.getReserveAToken(USDT) returns (address aToken) {
            uint256 userATokenBalance = IERC20(aToken).balanceOf(user);
            uint256 protocolATokenBalance = IERC20(aToken).balanceOf(LENDY_PROTOCOL);
            
            console.log("\nFinal aToken balances:");
            console.log("User:", userATokenBalance);
            console.log("LendyProtocol:", protocolATokenBalance);
            
            if (userATokenBalance > 0) {
                console.log("Supply successful - user has aTokens");
            } else {
                console.log("Supply may have failed - user has no aTokens");
            }
        } catch {
            console.log("Failed to check final aToken balances");
        }
    }
    
    function setCollateral() internal {
        console.log("\n=== Setting USDT as Collateral ===");
        
        // Check if user has aTokens
        bool hasATokens = false;
        
        try lendyProtocol.getReserveAToken(USDT) returns (address aTokenUSDT) {
            uint256 aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
            console.log("Current USDT aToken balance:", aTokenBalance);
            
            if (aTokenBalance > 0) {
                hasATokens = true;
            } else {
                console.log("No aToken balance. Supply USDT first.");
                supplyUSDT();
                
                // Check again after supplying
                aTokenBalance = IERC20(aTokenUSDT).balanceOf(user);
                hasATokens = aTokenBalance > 0;
                
                if (!hasATokens) {
                    console.log("Still no aToken balance after supplying. Cannot proceed.");
                    return;
                }
            }
        } catch {
            console.log("Could not get aToken for USDT");
            return;
        }
            
        if (hasATokens) {
            bool collateralSet = false;
            
            // Method 1: Try setting collateral through LendyProtocol
            console.log("\nMethod 1: Setting USDT as collateral through LendyProtocol");
            
            try lendyProtocol.setUserUseReserveAsCollateral(USDT, true) {
                console.log("Successfully set USDT as collateral through LendyProtocol");
                collateralSet = true;
            } catch Error(string memory reason) {
                console.log("Setting collateral via LendyProtocol failed:", reason);
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Setting collateral via LendyProtocol failed with error code:", errorCode);
                _decodeAaveError(errorCode);
                
                if (errorCode == 43) {
                    console.log("Error 43: UNDERLYING_BALANCE_ZERO - The protocol contract itself needs to have aTokens");
                    console.log("Will try direct AAVE Pool instead");
                }
            }
            
            // Method 2: Try setting collateral directly through AAVE Pool if first method failed
            if (!collateralSet) {
                console.log("\nMethod 2: Setting USDT as collateral directly through AAVE Pool");
                
                IPool pool = IPool(AAVE_POOL);
                
                try pool.setUserUseReserveAsCollateral(USDT, true) {
                    console.log("Successfully set USDT as collateral directly through AAVE Pool");
                    collateralSet = true;
                } catch Error(string memory reason) {
                    console.log("Setting collateral directly also failed:", reason);
                } catch (bytes memory reason) {
                    uint256 errorCode = _extractErrorCode(reason);
                    console.log("Setting collateral directly also failed with error code:", errorCode);
                    _decodeAaveError(errorCode);
                    
                    if (errorCode == 43) {
                        console.log("Error suggests no balance. Let's try explicit re-supply through AAVE directly...");
                        
                        // Re-supply a small amount directly through AAVE
                        uint256 supplyAmount = 50000; // 0.05 USDT
                        
                        if (IERC20(USDT).balanceOf(user) >= supplyAmount) {
                            // Approve USDT for the AAVE pool
                            IERC20(USDT).approve(AAVE_POOL, supplyAmount);
                            
                            try pool.supply(USDT, supplyAmount, user, 0) {
                                console.log("Successfully supplied additional USDT directly to AAVE Pool");
                                
                                // Try setting as collateral again
                                try pool.setUserUseReserveAsCollateral(USDT, true) {
                                    console.log("Successfully set USDT as collateral after direct supply");
                                    collateralSet = true;
                                } catch {
                                    console.log("Still failed to set collateral after direct supply");
                                }
                            } catch {
                                console.log("Failed to supply directly to AAVE Pool");
                            }
                        } else {
                            console.log("Not enough USDT for additional supply");
                        }
                    }
                }
            }
            
            // Verify collateral status
            (
                totalCollateralBase,
                totalDebtBase,
                availableBorrowsBase,
                ,
                ,
                healthFactor
            ) = lendyProtocol.getUserAccountData(user);
            
            console.log("\nUpdated account data:");
            console.log("Total Collateral (USD):", totalCollateralBase);
            console.log("Available Borrows (USD):", availableBorrowsBase);
            
            if (totalCollateralBase > 0 && availableBorrowsBase > 0) {
                console.log("USDT confirmed as collateral - borrowing is now possible");
            } else {
                console.log("Setting as collateral may have failed - no borrowing power");
                console.log("You may need to supply assets directly through AAVE, not through LendyProtocol");
            }
        }
    }
    
    function borrowUSDC() internal {
        console.log("\n=== Borrowing USDC through LendyProtocol ===");
        
        // Check if user has collateral and borrowing power
        (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            ,
            ,
            healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Before borrowing:");
        console.log("Total Collateral (USD):", totalCollateralBase);
        console.log("Total Debt (USD):", totalDebtBase);
        console.log("Available Borrows (USD):", availableBorrowsBase);
        console.log("Health Factor:", healthFactor);
        
        if (totalCollateralBase == 0 || availableBorrowsBase == 0) {
            console.log("Cannot borrow: No collateral or zero borrowing capacity");
            console.log("Make sure USDT is set as collateral first");
            return;
        }
        
        // Initial USDC balance
        uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);
        console.log("Initial USDC balance:", initialUsdcBalance);
        
        // Use a very small borrow amount to avoid potential issues
        uint256 borrowAmount = 10000; // 0.01 USDC with 6 decimals
        
        console.log("Attempting to borrow", borrowAmount, "USDC (0.01 USDC) through LendyProtocol");
        
        // Method 1: Try borrowing through LendyProtocol first
        console.log("\nMethod 1: Borrowing via LendyProtocol wrapper");
        bool borrowSuccess = false;
        
        try lendyProtocol.borrow(USDC, borrowAmount, 2, 0, user) { // Interest rate mode: 2 = variable
            console.log("Successfully borrowed USDC through LendyProtocol");
            borrowSuccess = true;
        } catch Error(string memory reason) {
            console.log("Borrowing via LendyProtocol failed:", reason);
        } catch (bytes memory reason) {
            uint256 errorCode = _extractErrorCode(reason);
            console.log("Borrowing via LendyProtocol failed with error code:", errorCode);
            _decodeAaveError(errorCode);
        }
        
        // Method 2: If LendyProtocol borrow fails, try direct AAVE Pool as fallback
        if (!borrowSuccess) {
            console.log("\nMethod 2: Borrowing directly via AAVE Pool as fallback");
            
            IPool pool = IPool(AAVE_POOL);
            
            try pool.borrow(USDC, borrowAmount, 2, 0, user) { // Interest rate mode: 2 = variable
                console.log("Successfully borrowed USDC directly through AAVE Pool");
                borrowSuccess = true;
            } catch Error(string memory reason) {
                console.log("Direct AAVE borrowing failed:", reason);
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Direct AAVE borrowing failed with error code:", errorCode);
                _decodeAaveError(errorCode);
                
                // Try with a tiny amount as last resort
                if (errorCode != 0) {
                    console.log("\nTrying with minimum possible amount as last resort");
                    uint256 minAmount = 1000; // 0.001 USDC
                    
                    try pool.borrow(USDC, minAmount, 2, 0, user) {
                        console.log("Successfully borrowed minimum USDC amount directly");
                        borrowSuccess = true;
                    } catch {
                        console.log("Even minimum amount borrowing failed directly");
                    }
                }
            }
        }
        
        // Check if any borrowing succeeded
        if (borrowSuccess) {
            // Check new USDC balance
            uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
            console.log("New USDC balance:", newUsdcBalance);
            console.log("USDC increase:", newUsdcBalance - initialUsdcBalance);
            
            // Check updated debt
            (
                totalCollateralBase,
                totalDebtBase,
                availableBorrowsBase,
                ,
                ,
                healthFactor
            ) = lendyProtocol.getUserAccountData(user);
            
            console.log("After borrowing:");
            console.log("Total Collateral (USD):", totalCollateralBase);
            console.log("Total Debt (USD):", totalDebtBase);
            console.log("Available Borrows (USD):", availableBorrowsBase);
            console.log("Health Factor:", healthFactor);
        } else {
            console.log("\nAll borrowing attempts failed.");
        }
    }
    
    function repayUSDC() internal {
        console.log("\n=== Repaying USDC Debt through LendyProtocol ===");
        
        // Check if user has debt
        (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            ,
            ,
            healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        console.log("Current debt status:");
        console.log("Total Debt (USD):", totalDebtBase);
        
        if (totalDebtBase == 0) {
            console.log("No debt to repay. Borrow some USDC first.");
            return;
        }
        
        // Check USDC balance
        uint256 usdcBalance = IERC20(USDC).balanceOf(user);
        console.log("USDC Balance:", usdcBalance);
        
        if (usdcBalance == 0) {
            console.log("No USDC available to repay debt.");
            return;
        }
        
        // Determine repayment amount - using AAVE_POOL to get the reserve data
        uint256 variableDebtBalance = 0;
        uint256 stableDebtBalance = 0;
        
        try IPool(AAVE_POOL).getReserveData(USDC) returns (DataTypes.ReserveData memory reserveData) {
            address stableDebtToken = reserveData.stableDebtTokenAddress;
            address variableDebtToken = reserveData.variableDebtTokenAddress;
            
            if (stableDebtToken != address(0)) {
                stableDebtBalance = IERC20(stableDebtToken).balanceOf(user);
                console.log("Stable Debt Token balance:", stableDebtBalance);
            }
            
            if (variableDebtToken != address(0)) {
                variableDebtBalance = IERC20(variableDebtToken).balanceOf(user);
                console.log("Variable Debt Token balance:", variableDebtBalance);
            }
        } catch {
            console.log("Could not fetch debt token balances");
            return;
        }
        
        // Determine which debt to repay (variable or stable)
        uint256 repayAmount;
        uint256 interestRateMode;
        
        if (variableDebtBalance > 0) {
            repayAmount = variableDebtBalance > usdcBalance ? usdcBalance : variableDebtBalance;
            interestRateMode = 2; // variable rate
            console.log("Repaying variable rate debt:", repayAmount);
        } else if (stableDebtBalance > 0) {
            repayAmount = stableDebtBalance > usdcBalance ? usdcBalance : stableDebtBalance;
            interestRateMode = 1; // stable rate
            console.log("Repaying stable rate debt:", repayAmount);
        } else {
            console.log("No specific USDC debt found despite totalDebtBase > 0");
            return;
        }
        
        // Approve USDC for repayment
        IERC20(USDC).approve(LENDY_PROTOCOL, repayAmount);
        
        // Repay through LendyProtocol
        try lendyProtocol.repay(USDC, repayAmount, interestRateMode, user) returns (uint256 actualRepayAmount) {
            console.log("Successfully repaid USDC through LendyProtocol, amount:", actualRepayAmount);
            
            // Check updated debt
            (
                totalCollateralBase,
                totalDebtBase,
                availableBorrowsBase,
                ,
                ,
                healthFactor
            ) = lendyProtocol.getUserAccountData(user);
                
            console.log("After repayment:");
            console.log("Total Collateral (USD):", totalCollateralBase);
            console.log("Total Debt (USD):", totalDebtBase);
            console.log("Available Borrows (USD):", availableBorrowsBase);
            console.log("Health Factor:", healthFactor);
        } catch Error(string memory reason) {
            console.log("Repayment failed:", reason);
        } catch (bytes memory reason) {
            uint256 errorCode = _extractErrorCode(reason);
            console.log("Repayment failed with error code:", errorCode);
            _decodeAaveError(errorCode);
        }
    }
    
    function createPosition() internal {
        console.log("\n=== Creating Position using LendyPositionManager ===");
        
        // Check if user has collateral and borrowing power
        (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            ,
            ,
            healthFactor
        ) = lendyProtocol.getUserAccountData(user);
        
        if (totalCollateralBase == 0) {
            console.log("No collateral. Need to supply and set collateral first.");
            supplyUSDT();
            setCollateral();
            
            // Check again after attempting to add collateral
            (
                totalCollateralBase,
                ,
                availableBorrowsBase,
                ,
                ,
                
            ) = lendyProtocol.getUserAccountData(user);
            
            if (totalCollateralBase == 0 || availableBorrowsBase == 0) {
                console.log("Still no collateral or borrowing power. Cannot create position.");
                return;
            }
        }
        
        // Check USDT balance for collateral
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        console.log("USDT balance:", usdtBalance);
        
        uint256 collateralAmount = 100000; // 0.1 USDT (6 decimals)
        uint256 borrowAmount = 10000;      // 0.01 USDC (6 decimals)
        
        if (usdtBalance < collateralAmount) {
            console.log("Not enough USDT for collateral. Need at least 0.1 USDT.");
            return;
        }
        
        // Method 1: Try using the LendyPositionManager
        console.log("\nMethod 1: Creating position via LendyPositionManager");
        
        // Approve USDT for position manager
        console.log("Approving USDT for position manager...");
        IERC20(USDT).approve(LENDY_POSITION_MANAGER, collateralAmount);
        
        bool positionCreated = false;
        
        try positionManager.createPosition(
            USDT,
            collateralAmount,
            USDC,
            borrowAmount,
            2 // Variable rate
        ) returns (uint256 positionId) {
            currentPositionId = positionId;
            console.log("Successfully created position with ID:", positionId);
            positionCreated = true;
            
            // Get position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
                console.log("Position details:");
                console.log("  Owner:", position.owner);
                console.log("  Collateral Asset:", position.collateralAsset);
                console.log("  Collateral Amount:", position.collateralAmount);
                console.log("  Borrow Asset:", position.borrowAsset);
                console.log("  Borrow Amount:", position.borrowAmount);
                console.log("  Interest Rate Mode:", position.interestRateMode);
                console.log("  Active:", position.active);
            } catch {
                console.log("Failed to get position details");
            }
            
            // Check USDC balance
            uint256 usdcBalance = IERC20(USDC).balanceOf(user);
            console.log("USDC balance after position creation:", usdcBalance);
            
        } catch Error(string memory reason) {
            console.log("Position creation via manager failed:", reason);
        } catch (bytes memory reason) {
            uint256 errorCode = _extractErrorCode(reason);
            console.log("Position creation via manager failed with error code:", errorCode);
            _decodeAaveError(errorCode);
        }
        
        // Method 2: If position manager fails, create position manually with direct AAVE interactions
        if (!positionCreated) {
            console.log("\nMethod 2: Creating position manually via direct AAVE Pool interactions");
            
            // Record initial USDC balance
            uint256 initialUsdcBalance = IERC20(USDC).balanceOf(user);
            console.log("Initial USDC balance:", initialUsdcBalance);
            
            // Use AAVE pool directly
            IPool pool = IPool(AAVE_POOL);
            
            // Step 1: Supply collateral directly to AAVE
            console.log("Step 1: Supplying USDT as collateral directly to AAVE...");
            IERC20(USDT).approve(AAVE_POOL, collateralAmount);
            
            bool supplySuccess = false;
            
            try pool.supply(USDT, collateralAmount, user, 0) {
                console.log("Successfully supplied USDT directly to AAVE Pool");
                supplySuccess = true;
            } catch Error(string memory reason) {
                console.log("Direct supply to AAVE failed:", reason);
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Direct supply to AAVE failed with error code:", errorCode);
                _decodeAaveError(errorCode);
            }
            
            if (!supplySuccess) {
                console.log("Failed to supply collateral directly. Manual position creation aborted.");
                return;
            }
            
            // Step 2: Set USDT as collateral
            console.log("Step 2: Setting USDT as collateral...");
            
            try pool.setUserUseReserveAsCollateral(USDT, true) {
                console.log("Successfully set USDT as collateral directly");
            } catch Error(string memory reason) {
                console.log("Setting collateral directly failed:", reason);
                console.log("Continuing anyway as it might already be set as collateral");
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Setting collateral directly failed with error code:", errorCode);
                _decodeAaveError(errorCode);
                console.log("Continuing anyway as it might already be set as collateral");
            }
            
            // Step 3: Borrow USDC
            console.log("Step 3: Borrowing USDC...");
            
            try pool.borrow(USDC, borrowAmount, 2, 0, user) { // Interest rate mode: 2 = variable
                console.log("Successfully borrowed USDC directly");
                
                uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
                console.log("New USDC balance:", newUsdcBalance);
                console.log("USDC borrowed:", newUsdcBalance - initialUsdcBalance);
                
                console.log("Manual position creation successful!");
            } catch Error(string memory reason) {
                console.log("Direct borrowing failed:", reason);
                
                // Try with smaller amount as last resort
                uint256 smallerAmount = 1000; // 0.001 USDC
                console.log("Trying with smaller amount:", smallerAmount);
                
                try pool.borrow(USDC, smallerAmount, 2, 0, user) {
                    console.log("Successfully borrowed smaller amount directly");
                    
                    uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
                    console.log("New USDC balance:", newUsdcBalance);
                    console.log("USDC borrowed:", newUsdcBalance - initialUsdcBalance);
                    
                    console.log("Manual position creation successful with reduced borrow amount!");
                } catch {
                    console.log("Failed to borrow even smaller amount. Manual position creation failed.");
                }
            } catch (bytes memory reason) {
                uint256 errorCode = _extractErrorCode(reason);
                console.log("Direct borrowing failed with error code:", errorCode);
                _decodeAaveError(errorCode);
                console.log("Manual position creation failed at borrowing step.");
            }
        }
        
        // Check final account status
        (
            totalCollateralBase,
            totalDebtBase,
            availableBorrowsBase,
            ,
            ,
            healthFactor
        ) = lendyProtocol.getUserAccountData(user);
            
        console.log("\nFinal account status:");
        console.log("Total Collateral (USD):", totalCollateralBase);
        console.log("Total Debt (USD):", totalDebtBase);
        console.log("Available Borrows (USD):", availableBorrowsBase);
        console.log("Health Factor:", healthFactor);
    }
    
    // Helper function to extract AAVE error codes
    function _extractErrorCode(bytes memory revertData) internal pure returns (uint256) {
        if (revertData.length < 68) {
            return 0; // Not enough data
        }
        
        uint256 errorCode;
        assembly {
            errorCode := mload(add(revertData, 0x44))
        }
        
        return errorCode;
    }
    
    // Helper function to decode AAVE error codes
    function _decodeAaveError(uint256 errorCode) internal pure {
        if (errorCode == 1) console.log("AAVE Error: CALLER_NOT_POOL_ADMIN");
        else if (errorCode == 2) console.log("AAVE Error: CALLER_NOT_EMERGENCY_ADMIN");
        else if (errorCode == 23) console.log("AAVE Error: CALLER_MUST_BE_POOL");
        else if (errorCode == 26) console.log("AAVE Error: INVALID_AMOUNT");
        else if (errorCode == 27) console.log("AAVE Error: RESERVE_INACTIVE");
        else if (errorCode == 28) console.log("AAVE Error: RESERVE_FROZEN");
        else if (errorCode == 29) console.log("AAVE Error: RESERVE_PAUSED");
        else if (errorCode == 30) console.log("AAVE Error: BORROWING_NOT_ENABLED");
        else if (errorCode == 31) console.log("AAVE Error: STABLE_BORROWING_NOT_ENABLED");
        else if (errorCode == 32) console.log("AAVE Error: COLLATERAL_BALANCE_IS_ZERO");
        else if (errorCode == 33) console.log("AAVE Error: HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD");
        else if (errorCode == 34) console.log("AAVE Error: COLLATERAL_CANNOT_COVER_NEW_BORROW");
        else if (errorCode == 35) console.log("AAVE Error: COLLATERAL_SAME_AS_BORROWING_CURRENCY");
        else if (errorCode == 43) console.log("AAVE Error: UNDERLYING_BALANCE_ZERO - The underlying balance needs to be greater than 0");
        else if (errorCode == 44) console.log("AAVE Error: HEALTH_FACTOR_NOT_BELOW_THRESHOLD");
        else if (errorCode == 45) console.log("AAVE Error: COLLATERAL_CANNOT_BE_LIQUIDATED");
        else if (errorCode == 48) console.log("AAVE Error: BORROW_CAP_EXCEEDED");
        else if (errorCode == 49) console.log("AAVE Error: SUPPLY_CAP_EXCEEDED");
        else if (errorCode == 55) console.log("AAVE Error: LTV_VALIDATION_FAILED");
        else if (errorCode == 57) console.log("AAVE Error: PRICE_ORACLE_SENTINEL_CHECK_FAILED");
        else if (errorCode == 58) console.log("AAVE Error: ASSET_NOT_BORROWABLE_IN_ISOLATION");
        else if (errorCode == 59) console.log("AAVE Error: RESERVE_ALREADY_INITIALIZED");
        else if (errorCode == 60) console.log("AAVE Error: USER_IN_ISOLATION_MODE_OR_LTV_ZERO");
        else console.log("AAVE Error: Unknown error code", errorCode);
    }
} 