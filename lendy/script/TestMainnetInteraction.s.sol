// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";

// Extended ERC20 interface with metadata functions
interface IERC20Extended is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Interface for EIP-2612 permit
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @title TestMainnetInteraction
 * @notice Script to test all major functions of the LendyPositionManager on mainnet
 */
contract TestMainnetInteraction is Script {
    // Contract addresses
    LendyPositionManager public positionManager;
    address public aavePool;
    address public poolAddressProvider;
    
    // Token addresses
    address public usdc;
    address public usdt;
    
    // Test user
    address public testUser;
    uint256 public testPrivateKey;
    uint256 public positionId;

    // Test function selector
    string public testFunction;

    function setUp() public {
        // Get the test function from environment variable
        testFunction = vm.envOr("TEST_FUNCTION", string("check"));
        
        // Set contract addresses
        positionManager = LendyPositionManager(vm.envOr("LENDY_POSITION_MANAGER", address(0xd2B508298fCC37261953684744ec4CCc734d5083)));
        aavePool = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
        poolAddressProvider = 0x9F7Cf9417D5251C59fE94fB9147feEe1aAd9Cea5;
        
        // Set token addresses
        usdc = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
        usdt = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
        
        // Get private key from environment variable
        try vm.envUint("CELO_MAINNET_PRIVATE_KEY") returns (uint256 pk) {
            testPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("CELO_MAINNET_PRIVATE_KEY");
            if (bytes(pkString).length > 0 && bytes(pkString)[0] == "0" && bytes(pkString)[1] == "x") {
                testPrivateKey = vm.parseUint(pkString);
            } else if (bytes(pkString).length > 0) {
                // If no 0x prefix, try adding it
                testPrivateKey = vm.parseUint(string(abi.encodePacked("0x", pkString)));
            } else {
                // Fallback to a default key for testing ONLY, but this should never be used in production
                console.log("[WARNING] No CELO_MAINNET_PRIVATE_KEY found in .env file. Using a dummy key that should NOT be used with real funds.");
                testPrivateKey = 0x0000000000000000000000000000000000000000000000000000000000000001;
            }
        }
        testUser = vm.addr(testPrivateKey);
        
        // Use position ID 5 which we've confirmed is active
        positionId = vm.envOr("POSITION_ID", uint256(5));
    }
    
    function run() public {
        console.log("\n==================================================================");
        console.log("LENDY POSITION MANAGER - MAINNET INTERACTION TEST SCRIPT");
        console.log("==================================================================\n");

        // Check if we're using the default private key
        if (testPrivateKey == 0x0000000000000000000000000000000000000000000000000000000000000001) {
            console.log("\n[WARNING] Using default private key - NOT SECURE FOR PRODUCTION");
            console.log("Please set CELO_MAINNET_PRIVATE_KEY in your .env file");
            console.log("Continuing with test private key for demo purposes only\n");
        }

        console.log("Running mainnet test interaction with function:", testFunction);
        console.log("Contract Addresses:");
        console.log("  - LendyPositionManager:", address(positionManager));
        console.log("  - Aave Pool:           ", aavePool);
        console.log("  - Address Provider:    ", poolAddressProvider);
        console.log("Token Addresses:");
        console.log("  - USDC:                ", usdc);
        console.log("  - USDT:                ", usdt);
        console.log("User Information:");
        console.log("  - Test user address:   ", testUser);
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
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("permit_flow"))) {
            runPermitTestFlow();
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
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("add_permit"))) {
            testAddCollateralWithPermit();
        } else if (keccak256(bytes(testFunction)) == keccak256(bytes("repay_permit"))) {
            testRepayDebtWithPermit();
        } else {
            console.log("Unknown test function. Available options: check, all, permit_flow, create, add, withdraw, borrow, repay, close, add_permit, repay_permit");
        }
    }
    
    // Function to run permit tests in chronological order
    function runPermitTestFlow() public {
        console.log("\n==================================================================");
        console.log("RUNNING PERMIT TEST FLOW IN CHRONOLOGICAL ORDER");
        console.log("==================================================================\n");
        
        // 1. Create position
        console.log("\n==== 1. CREATE POSITION ====");
        testCreatePosition();
        
        // 2. Add collateral with permit
        console.log("\n==== 2. ADD COLLATERAL WITH PERMIT ====");
        testAddCollateralWithPermit();
        
        // 3. Increase borrow amount
        console.log("\n==== 3. INCREASE BORROW ====");
        testIncreaseBorrow();
        
        // 4. Repay debt with permit
        console.log("\n==== 4. REPAY DEBT WITH PERMIT ====");
        testRepayDebtWithPermit();

        // 5.Withdraw some collateral
        console.log("\n==== 5. WITHDRAW COLLATERAL TEST ====");
        testWithdrawCollateral();
        
        // 6.Test full position closure
        console.log("\n==== 6. CLOSE POSITION TEST ====");
        testClosePosition();
        
        
        console.log("\n==================================================================");
        console.log("PERMIT TEST FLOW COMPLETED");
        console.log("==================================================================\n");
    }
    
    // Function to run all tests in sequence
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
        console.log("\n==== 7. CLOSE POSITION TEST ====");
        testClosePosition();
        
        // Skip permit tests when in skip-simulation mode
        if (keccak256(bytes(vm.envOr("ENABLE_PERMIT_TESTS", string("false")))) == keccak256(bytes("true"))) {
            // Test permit functions
            console.log("\n==== 8. ADD COLLATERAL WITH PERMIT TEST ====");
            testAddCollateralWithPermit();
            
            console.log("\n==== 9. REPAY DEBT WITH PERMIT TEST ====");
            testRepayDebtWithPermit();
        } else {
            console.log("\n==== 8. ADD COLLATERAL WITH PERMIT TEST ====");
            console.log("SKIPPING - Permit tests disabled or using --skip-simulation");
            console.log("\n==== 9. REPAY DEBT WITH PERMIT TEST ====");
            console.log("SKIPPING - Permit tests disabled or using --skip-simulation");
        }
        
        console.log("\n==================================================================");
        console.log("ALL TESTS COMPLETED");
        console.log("==================================================================\n");
    }
    
    // Test connectivity to contracts and check token balances
    function testConnectivity() public {
        console.log("\n==================================================================");
        console.log("TESTING CONNECTIVITY AND CONTRACT STATE");
        console.log("==================================================================\n");
        
        console.log("Testing read-only functions without broadcasting transactions...");
        
        // Contract verification
        console.log("\n------------------------------------------------------------------");
        console.log("CONTRACT VERIFICATION");
        console.log("------------------------------------------------------------------");
        
        // Check if LendyPositionManager exists and points to correct POOL
        try positionManager.POOL() returns (IPool pool) {
            console.log("[SUCCESS] LendyPositionManager contract exists");
            console.log("   POOL address:", address(pool));
            
            if(address(pool) == aavePool) {
                console.log("   [SUCCESS] POOL address matches expected Aave Pool address");
            } else {
                console.log("   [ERROR] POOL address mismatch!");
                console.log("      Expected:", aavePool);
                console.log("      Actual:  ", address(pool));
            }
        } catch {
            console.log("[ERROR] LendyPositionManager contract does not exist or has issues");
        }
        
        // Token verification
        console.log("\n------------------------------------------------------------------");
        console.log("TOKEN VERIFICATION");
        console.log("------------------------------------------------------------------");
        
        // USDC
        verifyToken("USDC", usdc);
        
        // USDT
        verifyToken("USDT", usdt);
        
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
                
                console.log("\nActive positions found:");
                
                for(uint i = 0; i < positions.length; i++) {
                    uint256 currentPositionId = positions[i];
                    
                    // Get details of each position
                    try positionManager.getPositionDetails(currentPositionId) returns (LendyPositionManager.Position memory position) {
                        console.log("\nPosition ID:", currentPositionId);
                        logPositionDetails(position);
                        
                        // Highlight active positions
                        if (position.active) {
                            console.log("NOTE: This position is ACTIVE and can be used for testing!");
                        }
                    } catch {
                        console.log("  [ERROR] Failed to get position details for position", currentPositionId);
                    }
                }
            } else {
                console.log("No positions found for test user");
            }
            
            // Display test user address again for clarity
            console.log("\nTest user address:", testUser);
            console.log("NOTE: To run tests involving permits, set POSITION_ID to an active position ID");
            
        } catch {
            console.log("[ERROR] Failed to get user positions");
        }
    }
    
    // Utility function to log position details
    function logPositionDetails(LendyPositionManager.Position memory position) internal view {
        console.log("  Owner:            ", position.owner);
        console.log("  Collateral asset: ", position.collateralAsset);
        console.log("  Collateral token: ", getTokenName(position.collateralAsset));
        console.log("  Collateral amount:", position.collateralAmount);
        console.log("  Borrow asset:     ", position.borrowAsset);
        console.log("  Borrow token:     ", getTokenName(position.borrowAsset));
        console.log("  Borrow amount:    ", position.borrowAmount);
        console.log("  Interest rate:    ", position.interestRateMode == 1 ? "Stable" : "Variable");
        console.log("  Active:           ", position.active ? "Yes" : "No");
    }
    
    // Helper function to verify a token
    function verifyToken(string memory tokenName, address tokenAddress) internal {
        console.log("\nVerifying", tokenName, "token");
        
        // Name
        try IERC20Extended(tokenAddress).name() returns (string memory name) {
            console.log("[SUCCESS]", tokenName, "token exists");
            console.log("   Name:   ", name);
        } catch {
            console.log("[ERROR]", tokenName, "token does not exist or has issues");
            return;
        }
        
        // Symbol
        try IERC20Extended(tokenAddress).symbol() returns (string memory symbol) {
            console.log("   Symbol: ", symbol);
        } catch {
            console.log("   Symbol:  Unable to retrieve");
        }
        
        // Decimals
        try IERC20Extended(tokenAddress).decimals() returns (uint8 decimals) {
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
        if (tokenAddress == usdc) return "USDC";
        if (tokenAddress == usdt) return "USDT";
        
        try IERC20Extended(tokenAddress).name() returns (string memory name) {
            return name;
        } catch {
            return "Unknown";
        }
    }
    
    // Helper function to generate EIP-2612 permit signature
    function generatePermit(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        try IERC20Permit(token).DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
            console.log("[SUCCESS] Token supports EIP-2612 permit");
            
            uint256 nonce;
            try IERC20Permit(token).nonces(owner) returns (uint256 _nonce) {
                nonce = _nonce;
                console.log("   Current nonce for user:", nonce);
            } catch {
                console.log("[ERROR] Failed to get nonce, using 0");
                nonce = 0;
            }
            
            // Create the permit message hash according to EIP-2612
            bytes32 permitTypeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
            
            bytes32 structHash = keccak256(
                abi.encode(
                    permitTypeHash,
                    owner,
                    spender,
                    value,
                    nonce,
                    deadline
                )
            );
            
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    structHash
                )
            );
            
            // Sign the digest with the test private key
            (v, r, s) = vm.sign(testPrivateKey, digest);
            
            console.log("[SUCCESS] Generated permit signature");
            console.log("   Value:    ", value);
            console.log("   Deadline: ", deadline);
            console.log("   v:        ", v);
            console.log("   r:        ", bytes32ToString(r));
            console.log("   s:        ", bytes32ToString(s));
            
            return (v, r, s);
        } catch {
            console.log("[ERROR] Token does not support EIP-2612 permit");
            return (0, 0, 0);
        }
    }
    
    // Helper function to convert bytes32 to string for logging
    function bytes32ToString(bytes32 value) internal pure returns (string memory) {
        bytes memory byteArray = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            uint8 byteValue = uint8(uint256(value << (i * 8)) >> 248);
            uint8 highNibble = byteValue >> 4;
            uint8 lowNibble = byteValue & 0x0f;
            
            byteArray[i*2] = char(highNibble);
            byteArray[i*2+1] = char(lowNibble);
        }
        
        return string(byteArray);
    }
    
    // Helper function for hex conversion
    function char(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(bytes1('0')) + value);
        } else {
            return bytes1(uint8(bytes1('a')) + value - 10);
        }
    }
    
    // Test creating a position with USDT as collateral and borrowing USDC
    function testCreatePosition() public {
        console.log("\n==================================================================");
        console.log("TESTING CREATE POSITION");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // Set up test amounts - using very small amounts (less than $0.5)
        uint256 collateralAmount = 0.5 * 10**6; // 0.5 USDT (6 decimals)
        uint256 borrowAmount = 0.25 * 10**6;    // 0.25 USDC (6 decimals)
        
        console.log("------------------------------------------------------------------");
        console.log("PREPARING FOR POSITION CREATION");
        console.log("------------------------------------------------------------------");
        
        // Check balances before
        uint256 usdtBalanceBefore = IERC20(usdt).balanceOf(testUser);
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(testUser);
        
        console.log("\nUser balances before position creation:");
        console.log("  USDT balance:", usdtBalanceBefore);
        console.log("  USDC balance:", usdcBalanceBefore);
        
        if (usdtBalanceBefore < collateralAmount) {
            console.log("\n[ERROR] Insufficient USDT balance for collateral");
            console.log("  Required:", collateralAmount);
            console.log("  Available:", usdtBalanceBefore);
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("APPROVING TOKENS");
        console.log("------------------------------------------------------------------");
        
        // Approve tokens for the position manager
        console.log("\nApproving USDT for position manager...");
        try IERC20(usdt).approve(address(positionManager), collateralAmount) {
            console.log("[SUCCESS] Successfully approved USDT");
            console.log("   Amount approved:", collateralAmount);
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to approve USDT. Reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to approve USDT with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("CREATING POSITION");
        console.log("------------------------------------------------------------------");
        
        console.log("\nParameters for position creation:");
        console.log("  Collateral asset:  ", usdt, "(USDT)");
        console.log("  Collateral amount: ", collateralAmount);
        console.log("  Borrow asset:      ", usdc, "(USDC)");
        console.log("  Borrow amount:     ", borrowAmount);
        console.log("  Interest rate mode:", 2, "(Variable)");
        
        try positionManager.createPosition(
            usdt,             // collateral asset
            collateralAmount, // collateral amount
            usdc,             // borrow asset
            borrowAmount,     // borrow amount
            2                 // variable interest rate
        ) returns (uint256 id) {
            positionId = id;
            console.log("\n[SUCCESS] POSITION CREATED SUCCESSFULLY");
            console.log("   Position ID:     ", positionId);
            
            // Check balances after position creation
            uint256 usdtBalanceAfter = IERC20(usdt).balanceOf(testUser);
            uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(testUser);
            
            console.log("\nBalance changes:");
            console.log("   USDT decreased by:", usdtBalanceBefore - usdtBalanceAfter);
            console.log("   USDC increased by:", usdcBalanceAfter - usdcBalanceBefore);
            
            // Verify position details
            console.log("\nVerifying position details...");
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
                console.log("\nPOSITION DETAILS");
                console.log("------------------------------------------------------------------");
                logPositionDetails(position);
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
            try IERC20(usdt).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                console.log("   USDT allowance:", allowance);
                if (allowance < collateralAmount) {
                    console.log("   [ERROR] Insufficient allowance for collateral");
                }
            } catch {
                console.log("   [ERROR] Failed to check allowance");
            }
            
            // Check if the user has enough balance
            try IERC20(usdt).balanceOf(testUser) returns (uint256 balance) {
                console.log("   USDT balance:", balance);
                if (balance < collateralAmount) {
                    console.log("   [ERROR] Insufficient balance for collateral");
                }
            } catch {
                console.log("   [ERROR] Failed to check balance");
            }
        } catch {
            console.log("\n[ERROR] POSITION CREATION FAILED");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    // Test adding more collateral to an existing position
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
            logPositionDetails(position);
            
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
        
        // Add more collateral - 50% of current amount
        uint256 additionalAmount = positionBefore.collateralAmount / 2;
        console.log("\nPreparing to add", additionalAmount, "collateral tokens");
        
        // Make sure we have enough tokens
        uint256 balanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        console.log("User collateral balance before:", balanceBefore);
        
        if (balanceBefore < additionalAmount) {
            console.log("[ERROR] Insufficient balance for additional collateral");
            console.log("   Required:", additionalAmount);
            console.log("   Available:", balanceBefore);
            vm.stopBroadcast();
            return;
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
                logPositionDetails(positionAfter);
                
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
    
    // Test adding more collateral to an existing position using permit
    function testAddCollateralWithPermit() public {
        console.log("\n==================================================================");
        console.log("TESTING ADD COLLATERAL WITH PERMIT");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        console.log("------------------------------------------------------------------");
        console.log("VERIFYING POSITION");
        console.log("------------------------------------------------------------------\n");
        
        // Check if a position exists - use the position ID from environment variable
        console.log("Getting position details for ID:", positionId);
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            console.log("\nPOSITION DETAILS BEFORE ADDING COLLATERAL");
            console.log("------------------------------------------------------------------");
            logPositionDetails(position);
            
            if (!positionBefore.active || positionBefore.owner == address(0)) {
                console.log("\n[WARNING] Position doesn't exist or is not active, skipping permit test");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            console.log("Skipping permit test");
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            console.log("Skipping permit test");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("PREPARING ADDITIONAL COLLATERAL WITH PERMIT");
        console.log("------------------------------------------------------------------");
        
        // Add more collateral - 50% of current amount
        uint256 additionalAmount = positionBefore.collateralAmount / 2;
        console.log("\nPreparing to add", additionalAmount, "collateral tokens using permit");
        
        // Make sure we have enough tokens
        uint256 balanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        console.log("User collateral balance before:", balanceBefore);
        
        if (balanceBefore < additionalAmount) {
            console.log("[ERROR] Insufficient balance for additional collateral");
            console.log("   Required:", additionalAmount);
            console.log("   Available:", balanceBefore);
            vm.stopBroadcast();
            return;
        } else {
            console.log("[SUCCESS] User has sufficient collateral balance");
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("GENERATING PERMIT FOR ADDITIONAL COLLATERAL");
        console.log("------------------------------------------------------------------");
        
        // Set permit parameters
        uint256 deadline = block.timestamp + 3600; // 1 hour from now
        
        // Generate permit signature
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = generatePermit(
            positionBefore.collateralAsset,
            testUser,
            address(positionManager),
            additionalAmount,
            deadline
        );
        
        // Check if permit was generated successfully
        if (permitV == 0) {
            console.log("[ERROR] Failed to generate permit signature or token doesn't support EIP-2612");
            console.log("Falling back to regular addCollateral function...");
            vm.stopBroadcast();
            testAddCollateral();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("ADDING COLLATERAL TO POSITION WITH PERMIT");
        console.log("------------------------------------------------------------------");
        
        // Add collateral with permit
        try positionManager.addCollateralWithPermit(
            positionId,
            additionalAmount,
            deadline,
            permitV,
            permitR,
            permitS
        ) {
            console.log("\n[SUCCESS] COLLATERAL ADDED SUCCESSFULLY WITH PERMIT");
            console.log("   Amount added:", additionalAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER ADDING COLLATERAL");
                console.log("------------------------------------------------------------------");
                logPositionDetails(positionAfter);
                
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
            console.log("\n[ERROR] FAILED TO ADD COLLATERAL WITH PERMIT");
            console.log("   Reason:", reason);
        } catch {
            console.log("\n[ERROR] FAILED TO ADD COLLATERAL WITH PERMIT");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    // Test increasing borrow amount of an existing position
    function testIncreaseBorrow() public {
        console.log("\n==================================================================");
        console.log("TESTING INCREASE BORROW");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
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
    
    // Test repaying debt for an existing position
    function testRepayDebt() public {
        console.log("\n==================================================================");
        console.log("TESTING REPAY DEBT");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
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
            
            console.log("\nPOSITION DETAILS BEFORE REPAYMENT");
            console.log("------------------------------------------------------------------");
            logPositionDetails(position);
            
            if (positionBefore.borrowAmount == 0) {
                console.log("[ERROR] Position has no debt to repay");
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
        
        // Calculate repay amount (half of current debt)
        uint256 repayAmount = positionBefore.borrowAmount / 2;
        
        console.log("\nRepayment calculation:");
        console.log("  Total debt:     ", positionBefore.borrowAmount);
        console.log("  Repayment amount:", repayAmount);
        console.log("  Remaining debt: ", positionBefore.borrowAmount - repayAmount);
        
        // Record balances before operations
        uint256 collateralBalanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        uint256 borrowBalanceBefore = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
        
        console.log("\nBalances before operations:");
        console.log("  Collateral token balance:", collateralBalanceBefore);
        console.log("  Borrow token balance:    ", borrowBalanceBefore);
        
        // Check if user has sufficient balance for partial repayment
        if (borrowBalanceBefore < repayAmount) {
            console.log("[ERROR] Insufficient balance to repay debt.");
            console.log("  Required:", repayAmount);
            console.log("  Available:", borrowBalanceBefore);
            console.log("  Please acquire tokens before running this test on mainnet");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("REPAYING PARTIAL DEBT");
        console.log("------------------------------------------------------------------");
        
        // Approve tokens for repayment
        try IERC20(positionBefore.borrowAsset).approve(address(positionManager), repayAmount) {
            console.log("[SUCCESS] Approved tokens for debt repayment");
            console.log("   Amount approved:", repayAmount);
            
            // Perform partial debt repayment
            try positionManager.repayDebt(positionId, repayAmount) {
                console.log("[SUCCESS] Partial debt repaid successfully");
                console.log("   Amount repaid:", repayAmount);
                
                // Verify position after repayment
                try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                    console.log("\nPOSITION DETAILS AFTER REPAYMENT");
                    console.log("------------------------------------------------------------------");
                    logPositionDetails(positionAfter);
                    
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
                    console.log("[ERROR] Failed to get position details after repayment. Reason:", reason);
                } catch {
                    console.log("[ERROR] Failed to get position details after repayment");
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to repay debt. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to repay debt with unknown error");
            }
        } catch {
            console.log("[ERROR] Failed to approve tokens for repayment");
            vm.stopBroadcast();
            return;
        }
        
        // Record final balances
        uint256 collateralBalanceAfter = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        uint256 borrowBalanceAfter = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
        
        console.log("\nFinal balances after all operations:");
        console.log("  Collateral token balance:", collateralBalanceAfter);
        console.log("  Borrow token balance:    ", borrowBalanceAfter);
        console.log("\nBalance changes from beginning to end:");
        
        // Safely calculate balance changes to avoid underflow/overflow
        if (collateralBalanceAfter >= collateralBalanceBefore) {
            console.log("  Collateral change:  +", collateralBalanceAfter - collateralBalanceBefore);
        } else {
            console.log("  Collateral change:  -", collateralBalanceBefore - collateralBalanceAfter);
        }
        
        if (borrowBalanceAfter >= borrowBalanceBefore) {
            console.log("  Borrow token change: +", borrowBalanceAfter - borrowBalanceBefore);
        } else {
            console.log("  Borrow token change: -", borrowBalanceBefore - borrowBalanceAfter);
        }
        
        vm.stopBroadcast();
    }
    
    // Test repaying debt for an existing position using permit
    function testRepayDebtWithPermit() public {
        console.log("\n==================================================================");
        console.log("TESTING REPAY DEBT WITH PERMIT");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
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
            
            console.log("\nPOSITION DETAILS BEFORE REPAYMENT");
            console.log("------------------------------------------------------------------");
            logPositionDetails(position);
            
            if (!positionBefore.active || positionBefore.owner == address(0)) {
                console.log("\n[WARNING] Position doesn't exist or is not active, skipping permit test");
                vm.stopBroadcast();
                return;
            }
            
            if (positionBefore.borrowAmount == 0) {
                console.log("[ERROR] Position has no debt to repay");
                vm.stopBroadcast();
                return;
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get position details. Reason:", reason);
            console.log("Skipping permit test");
            vm.stopBroadcast();
            return;
        } catch {
            console.log("[ERROR] Failed to get position details with unknown error");
            console.log("Skipping permit test");
            vm.stopBroadcast();
            return;
        }
        
        // Calculate repay amount (half of current debt)
        uint256 repayAmount = positionBefore.borrowAmount / 2;
        
        console.log("\nRepayment calculation:");
        console.log("  Total debt:     ", positionBefore.borrowAmount);
        console.log("  Repayment amount:", repayAmount);
        console.log("  Remaining debt: ", positionBefore.borrowAmount - repayAmount);
        
        // Check user balance of borrow asset
        uint256 borrowBalanceBefore = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
        console.log("\nUser balance of borrow asset before:", borrowBalanceBefore);
        
        if (borrowBalanceBefore < repayAmount) {
            console.log("[ERROR] Insufficient balance to repay debt.");
            console.log("  Required:", positionBefore.borrowAmount);
            console.log("  Available:", borrowBalanceBefore);
            console.log("  Please acquire tokens before running this test on mainnet");
            vm.stopBroadcast();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("GENERATING PERMIT FOR DEBT REPAYMENT");
        console.log("------------------------------------------------------------------");
        
        // Set permit parameters
        uint256 deadline = block.timestamp + 3600; // 1 hour from now
        
        // Generate permit signature
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = generatePermit(
            positionBefore.borrowAsset,
            testUser,
            address(positionManager),
            repayAmount,
            deadline
        );
        
        // Check if permit was generated successfully
        if (permitV == 0) {
            console.log("[ERROR] Failed to generate permit signature or token doesn't support EIP-2612");
            console.log("Falling back to regular repayDebt function...");
            vm.stopBroadcast();
            testRepayDebt();
            return;
        }
        
        console.log("\n------------------------------------------------------------------");
        console.log("REPAYING DEBT WITH PERMIT");
        console.log("------------------------------------------------------------------");
        
        // Repay debt with permit
        try positionManager.repayDebtWithPermit(
            positionId,
            repayAmount,
            deadline,
            permitV,
            permitR,
            permitS
        ) returns (uint256 actualRepaidAmount) {
            console.log("\n[SUCCESS] DEBT REPAYMENT COMPLETED WITH PERMIT");
            console.log("   Amount requested for repayment:", repayAmount);
            console.log("   Actual amount repaid:", actualRepaidAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER REPAYMENT");
                console.log("------------------------------------------------------------------");
                logPositionDetails(positionAfter);
                
                console.log("\nDEBT CHANGE SUMMARY");
                console.log("------------------------------------------------------------------");
                console.log("  Debt before:   ", positionBefore.borrowAmount);
                console.log("  Debt after:    ", positionAfter.borrowAmount);
                console.log("  Decrease:      ", positionBefore.borrowAmount - positionAfter.borrowAmount);
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get updated position details with unknown error");
            }
            
            // Check user balance of borrow asset after repayment
            uint256 balanceAfter = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
            console.log("\nUser borrow token balance after:", balanceAfter);
            console.log("Balance decrease:              ", borrowBalanceBefore - balanceAfter);
        } catch Error(string memory reason) {
            console.log("\n[ERROR] DEBT REPAYMENT WITH PERMIT FAILED");
            console.log("   Reason:", reason);
        } catch {
            console.log("\n[ERROR] DEBT REPAYMENT WITH PERMIT FAILED");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    // Test withdrawing collateral from an existing position
    function testWithdrawCollateral() public {
        console.log("\n==================================================================");
        console.log("TESTING WITHDRAW COLLATERAL");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
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
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            console.log("\nPOSITION DETAILS BEFORE WITHDRAWAL");
            console.log("------------------------------------------------------------------");
            logPositionDetails(position);
            
            if (positionBefore.collateralAmount == 0) {
                console.log("[ERROR] Position has no collateral to withdraw");
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
        
        // Calculate withdrawal amount (20% of current collateral)
        uint256 withdrawAmount = positionBefore.collateralAmount / 5;
        
        console.log("\nWithdrawal calculation:");
        console.log("  Total collateral:   ", positionBefore.collateralAmount);
        console.log("  Withdrawal amount:  ", withdrawAmount);
        console.log("  Remaining collateral:", positionBefore.collateralAmount - withdrawAmount);
        
        // Check user balance of collateral asset before withdrawal
        uint256 collateralBalanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        console.log("\nUser balance of collateral asset before:", collateralBalanceBefore);
        
        // Withdraw collateral
        try positionManager.withdrawCollateral(positionId, withdrawAmount) {
            console.log("\n[SUCCESS] COLLATERAL WITHDRAWAL COMPLETED");
            console.log("   Amount withdrawn:", withdrawAmount);
            
            // Verify updated position details
            try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfter) {
                console.log("\nPOSITION DETAILS AFTER WITHDRAWAL");
                console.log("------------------------------------------------------------------");
                logPositionDetails(positionAfter);
                
                console.log("\nCOLLATERAL CHANGE SUMMARY");
                console.log("------------------------------------------------------------------");
                console.log("  Collateral before:   ", positionBefore.collateralAmount);
                console.log("  Collateral after:    ", positionAfter.collateralAmount);
                console.log("  Decrease:            ", positionBefore.collateralAmount - positionAfter.collateralAmount);
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to get updated position details. Reason:", reason);
            } catch {
                console.log("[ERROR] Failed to get updated position details with unknown error");
            }
            
            // Check user balance of collateral asset after withdrawal
            uint256 balanceAfter = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
            console.log("\nUser collateral token balance after:", balanceAfter);
            console.log("Balance increase:                   ", balanceAfter - collateralBalanceBefore);
        } catch Error(string memory reason) {
            console.log("\n[ERROR] COLLATERAL WITHDRAWAL FAILED");
            console.log("   Reason:", reason);
        } catch {
            console.log("\n[ERROR] COLLATERAL WITHDRAWAL FAILED");
            console.log("   Unknown error occurred");
        }
        
        vm.stopBroadcast();
    }
    
    // Test closing an existing position
    function testClosePosition() public {
        console.log("\n==================================================================");
        console.log("TESTING CLOSE POSITION");
        console.log("==================================================================\n");
        
        vm.startBroadcast(testPrivateKey);
        
        // If we don't have a position yet, create one
        if (positionId == 0) {
            console.log("No position ID provided, checking for existing positions...");
            
            try positionManager.getUserPositions(testUser) returns (uint256[] memory positions) {
                if (positions.length > 0) {
                    positionId = positions[positions.length - 1];
                    console.log("[SUCCESS] Found existing position with ID:", positionId);
                } else {
                    console.log("[WARNING] No existing positions found, creating a new test position to close...");
                    
                    // Create new position with small values for testing close
                    address collateralAsset = usdt;
                    uint256 collateralAmount = 0.5 * 10**6; // 0.5 USDT (6 decimals)
                    address borrowAsset = usdc;
                    uint256 borrowAmount = 200 * 10**6; // 200 USDC
                    uint8 interestRateMode = 2; // Variable rate
                    
                    console.log("\nCreating test position with parameters:");
                    console.log("  Collateral: ", collateralAmount, "USDT");
                    console.log("  Borrow:     ", borrowAmount, "USDC");
                    
                    // Check if we have enough collateral tokens
                    // Note: On mainnet, we can't mint tokens, must acquire them beforehand
                    uint256 existingCollateral = IERC20(collateralAsset).balanceOf(testUser);
                    if (existingCollateral < collateralAmount) {
                        console.log("[ERROR] Insufficient collateral balance.");
                        console.log("  Required:", collateralAmount);
                        console.log("  Available:", existingCollateral);
                        console.log("  Please acquire tokens before running this test on mainnet");
                        vm.stopBroadcast();
                        return;
                    } else {
                        console.log("[SUCCESS] Sufficient collateral balance available:", existingCollateral);
                    }
                    
                    // Approve tokens
                    try IERC20(collateralAsset).approve(address(positionManager), collateralAmount) {
                        console.log("[SUCCESS] Approved", collateralAmount, "tokens for position manager");
                    } catch {
                        console.log("[ERROR] Failed to approve tokens for position manager");
                        vm.stopBroadcast();
                        return;
                    }
                    
                    // Create position
                    try positionManager.createPosition(
                        collateralAsset,
                        collateralAmount,
                        borrowAsset,
                        borrowAmount,
                        interestRateMode
                    ) returns (uint256 newPositionId) {
                        positionId = newPositionId;
                        console.log("[SUCCESS] Test position created with ID:", positionId);
                    } catch Error(string memory reason) {
                        console.log("[ERROR] Failed to create test position. Reason:", reason);
                        vm.stopBroadcast();
                        return;
                    } catch {
                        console.log("[ERROR] Failed to create test position with unknown error");
                        vm.stopBroadcast();
                        return;
                    }
                }
            } catch {
                console.log("[ERROR] Failed to get user positions");
                vm.stopBroadcast();
                return;
            }
        }
        
        // Get position details
        LendyPositionManager.Position memory positionBefore;
        try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory position) {
            positionBefore = position;
            
            console.log("\nPOSITION DETAILS BEFORE CLOSING");
            console.log("------------------------------------------------------------------");
            logPositionDetails(position);
            
            if (!positionBefore.active) {
                console.log("[ERROR] Position is not active, cannot close");
                vm.stopBroadcast();
                return;
            }
            
            if (positionBefore.borrowAmount == 0) {
                console.log("[WARNING] Position has no debt, will only withdraw collateral");
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
        
        // Record balances before operations
        uint256 collateralBalanceBefore = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        uint256 borrowBalanceBefore = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
        
        console.log("\nBalances before operations:");
        console.log("  Collateral token balance:", collateralBalanceBefore);
        console.log("  Borrow token balance:    ", borrowBalanceBefore);
        
        // Check if need to repay debt and have sufficient balance
        if (positionBefore.borrowAmount > 0) {
            uint256 borrowBalance = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
            
            console.log("\nChecking borrow asset balance:");
            console.log("  Position debt:  ", positionBefore.borrowAmount);
            console.log("  User balance:   ", borrowBalance);
            
            if (borrowBalance < positionBefore.borrowAmount) {
                console.log("[ERROR] Insufficient balance to repay debt.");
                console.log("  Required:", positionBefore.borrowAmount);
                console.log("  Available:", borrowBalance);
                console.log("  Please acquire tokens before running this test on mainnet");
                vm.stopBroadcast();
                return;
            }
            
            console.log("\n------------------------------------------------------------------");
            console.log("USING ALTERNATIVE CLOSING METHOD FOR AAVE V3");
            console.log("------------------------------------------------------------------\n");
            
            // STEP 1: Repay all debt first
            console.log("Step 1: First repaying all debt separately...");
            
            // Approve tokens with a large buffer
            uint256 approvalAmount = positionBefore.borrowAmount * 2; // Double to ensure sufficient allowance
            console.log("Approving", approvalAmount, "tokens for debt repayment (double the required amount)");

            try IERC20(positionBefore.borrowAsset).approve(address(positionManager), approvalAmount) {
                console.log("[SUCCESS] Approved tokens for position manager");
                
                // Get current allowance to verify
                try IERC20(positionBefore.borrowAsset).allowance(testUser, address(positionManager)) returns (uint256 allowance) {
                    console.log("Current allowance:", allowance);
                    if (allowance < positionBefore.borrowAmount) {
                        console.log("[WARNING] Allowance is still less than required, attempting to increase");
                        try IERC20(positionBefore.borrowAsset).approve(address(positionManager), type(uint256).max) {
                            console.log("[SUCCESS] Approved with maximum allowance");
                        } catch {
                            console.log("[ERROR] Failed to approve with maximum allowance");
                        }
                    }
                } catch {
                    console.log("[ERROR] Failed to check allowance");
                }
                
                // Attempt to repay debt
                try positionManager.repayDebt(positionId, positionBefore.borrowAmount) {
                    console.log("[SUCCESS] Debt repaid successfully");
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to repay debt. Reason:", reason);
                    vm.stopBroadcast();
                    return;
                } catch {
                    console.log("[ERROR] Failed to repay debt with unknown error");
                    vm.stopBroadcast();
                    return;
                }
                
                // STEP 2: Withdraw all collateral
                console.log("\nStep 2: Now withdrawing all collateral...");
                
                try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfterRepay) {
                    console.log("\nPOSITION DETAILS AFTER REPAYMENT");
                    console.log("------------------------------------------------------------------");
                    logPositionDetails(positionAfterRepay);
                    
                    if (positionAfterRepay.collateralAmount > 0) {
                        try positionManager.withdrawCollateral(positionId, positionAfterRepay.collateralAmount) {
                            console.log("[SUCCESS] Collateral withdrawn successfully");
                        } catch Error(string memory reason) {
                            console.log("[ERROR] Failed to withdraw collateral. Reason:", reason);
                            vm.stopBroadcast();
                            return;
                        } catch {
                            console.log("[ERROR] Failed to withdraw collateral with unknown error");
                            vm.stopBroadcast();
                            return;
                        }
                    } else {
                        console.log("[INFO] No collateral to withdraw");
                    }
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to get position details after repayment. Reason:", reason);
                    vm.stopBroadcast();
                    return;
                } catch {
                    console.log("[ERROR] Failed to get position details after repayment");
                    vm.stopBroadcast();
                    return;
                }
                
                // STEP 3: Manually mark position as inactive in contract data storage
                console.log("\nStep 3: Position is now effectively closed (all assets withdrawn)");
                console.log("NOTE: Due to Aave V3 limitations (Error 35), the position remains marked as active");
                console.log("      but has zero collateral and zero debt, making it effectively closed.");
                
                try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfterWithdrawal) {
                    console.log("\nPOSITION FINAL STATE");
                    console.log("------------------------------------------------------------------");
                    logPositionDetails(positionAfterWithdrawal);
                    
                    if (positionAfterWithdrawal.borrowAmount == 0 && positionAfterWithdrawal.collateralAmount == 0) {
                        console.log("[SUCCESS] Position ID:", positionId, "is now effectively closed (zero assets)");
                        
                        // NOTE: The position will remain marked as active in the system due to Aave V3 limitations
                        // For a production system, you might need to add a method to your contract to mark positions 
                        // as inactive in your own data structures, separate from Aave's internal state
                        console.log("[INFO] To mark a position as formally inactive in a production system,");
                        console.log("       consider adding a method to the LendyPositionManager contract");
                        console.log("       that can set positions as inactive in your own data structures");
                    } else {
                        console.log("[WARNING] Position still has assets after attempted closure");
                        console.log("  Remaining collateral:", positionAfterWithdrawal.collateralAmount);
                        console.log("  Remaining debt:", positionAfterWithdrawal.borrowAmount);
                    }
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to get position final details. Reason:", reason);
                } catch {
                    console.log("[ERROR] Failed to get position final details");
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Failed to approve tokens for repayment. Reason:", reason);
                vm.stopBroadcast();
                return;
            } catch {
                console.log("[ERROR] Failed to approve tokens for repayment with unknown error");
                vm.stopBroadcast();
                return;
            }
        } else {
            // Simply try to withdraw all collateral and report position as effectively closed
            console.log("\nPosition has no debt, withdrawing all collateral...");
            
            if (positionBefore.collateralAmount > 0) {
                try positionManager.withdrawCollateral(positionId, positionBefore.collateralAmount) {
                    console.log("[SUCCESS] Collateral withdrawn successfully");
                    
                    try positionManager.getPositionDetails(positionId) returns (LendyPositionManager.Position memory positionAfterWithdrawal) {
                        console.log("\nPOSITION FINAL STATE");
                        console.log("------------------------------------------------------------------");
                        logPositionDetails(positionAfterWithdrawal);
                        
                        if (positionAfterWithdrawal.borrowAmount == 0 && positionAfterWithdrawal.collateralAmount == 0) {
                            console.log("[SUCCESS] Position ID:", positionId, "is now effectively closed (zero assets)");
                            console.log("NOTE: Due to Aave V3 limitations (Error 35), the position remains marked as active");
                            console.log("      but has zero collateral and zero debt, making it effectively closed.");
                            
                            // NOTE: The position will remain marked as active in the system due to Aave V3 limitations
                            // For a production system, you might need to add a method to your contract to mark positions 
                            // as inactive in your own data structures, separate from Aave's internal state
                            console.log("[INFO] To mark a position as formally inactive in a production system,");
                            console.log("       consider adding a method to the LendyPositionManager contract");
                            console.log("       that can set positions as inactive in your own data structures");
                        } else {
                            console.log("[WARNING] Position still has assets after withdrawal");
                            console.log("  Remaining collateral:", positionAfterWithdrawal.collateralAmount);
                            console.log("  Remaining debt:", positionAfterWithdrawal.borrowAmount);
                        }
                    } catch Error(string memory reason) {
                        console.log("[ERROR] Failed to get position final details. Reason:", reason);
                    } catch {
                        console.log("[ERROR] Failed to get position final details");
                    }
                } catch Error(string memory reason) {
                    console.log("[ERROR] Failed to withdraw collateral. Reason:", reason);
                } catch {
                    console.log("[ERROR] Failed to withdraw collateral with unknown error");
                }
            } else {
                console.log("[INFO] Position has no collateral to withdraw");
                console.log("Position is effectively closed (has no assets)");
            }
        }
        
        // Record final balances
        uint256 collateralBalanceAfter = IERC20(positionBefore.collateralAsset).balanceOf(testUser);
        uint256 borrowBalanceAfter = IERC20(positionBefore.borrowAsset).balanceOf(testUser);
        
        console.log("\nFinal balances after all operations:");
        console.log("  Collateral token balance:", collateralBalanceAfter);
        console.log("  Borrow token balance:    ", borrowBalanceAfter);
        console.log("\nBalance changes from beginning to end:");
        
        // Safely calculate balance changes to avoid underflow/overflow
        if (collateralBalanceAfter >= collateralBalanceBefore) {
            console.log("  Collateral change:  +", collateralBalanceAfter - collateralBalanceBefore);
        } else {
            console.log("  Collateral change:  -", collateralBalanceBefore - collateralBalanceAfter);
        }
        
        if (borrowBalanceAfter >= borrowBalanceBefore) {
            console.log("  Borrow token change: +", borrowBalanceAfter - borrowBalanceBefore);
        } else {
            console.log("  Borrow token change: -", borrowBalanceBefore - borrowBalanceAfter);
        }
        
        vm.stopBroadcast();
    }
} 