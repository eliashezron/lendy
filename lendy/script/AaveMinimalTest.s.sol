// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol"; // Import Test for deal cheatcode

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
}

/**
 * @title AaveMinimalTest
 * @notice Minimal script to diagnose AAVE borrowing issues
 */
contract AaveMinimalTest is Script, Test {
    // AAVE Pool
    address constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    
    // Token addresses (Celo mainnet)
    address constant USDC = 0xef4229c8c3250C675F21BCefa42f58EfbfF6002a;
    address constant USDT = 0x88eeC49252c8cbc039DCdB394c0c2BA2f1637EA0;
    
    // User info
    address public user;
    
    // Minimum amounts for testing
    uint256 constant MIN_USDT_SUPPLY = 0.05 ether; // 0.05 USDT (scaled to 18 decimals for calculation)
    
    IPool aavePool = IPool(AAVE_POOL);
    
    function setUp() public {
        // No action needed for this test
        user = msg.sender;
    }
    
    // Function to mint test tokens
    function mintTestTokens() internal {
        // Get token decimals
        uint8 usdtDecimals = IERC20(USDT).decimals();
        uint8 usdcDecimals = IERC20(USDC).decimals();
        
        // Calculate amounts with proper decimals
        uint256 usdtAmount = 10 * (10 ** usdtDecimals); // 10 USDT
        uint256 usdcAmount = 10 * (10 ** usdcDecimals); // 10 USDC
        
        // Use deal cheatcode to mint tokens
        deal(address(user), 1 ether); // Give some ETH for gas
        deal(USDT, user, usdtAmount);
        deal(USDC, user, usdcAmount);
        
        console2.log("Minted %d USDT and %d USDC for testing", usdtAmount / (10 ** usdtDecimals), usdcAmount / (10 ** usdcDecimals));
    }
    
    function run() public {
        console2.log("AaveMinimalTest started");
        console2.log("AAVE Pool:", AAVE_POOL);
        console2.log("User Address:", user);
        
        // Start broadcast without private key (using the default sender)
        vm.startBroadcast();
        
        // Mint test tokens for testing
        mintTestTokens();
        
        // Check user balances
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        uint256 usdcBalance = IERC20(USDC).balanceOf(user);
        uint8 usdtDecimals = IERC20(USDT).decimals();
        uint8 usdcDecimals = IERC20(USDC).decimals();
        
        console2.log("Initial USDT Balance:", usdtBalance / (10 ** usdtDecimals));
        console2.log("Initial USDC Balance:", usdcBalance / (10 ** usdcDecimals));
        
        // Minimum amount to supply (0.05 USDT)
        uint256 minSupplyAmount = 5 * (10 ** (usdtDecimals - 2));
        
        if (usdtBalance < minSupplyAmount) {
            console2.log("Not enough USDT available. Need at least 0.05 USDT");
            vm.stopBroadcast();
            return;
        }
        
        // Approve USDT spending
        IERC20(USDT).approve(AAVE_POOL, usdtBalance);
        console2.log("Approved AAVE to spend USDT");
        
        // Supply USDT to AAVE
        aavePool.supply(USDT, minSupplyAmount, user, 0);
        console2.log("Supplied 0.05 USDT to AAVE");
        
        // Enable USDT as collateral
        aavePool.setUserUseReserveAsCollateral(USDT, true);
        console2.log("Set USDT as collateral");
        
        // Check account data after supplying
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = aavePool.getUserAccountData(user);
        
        console2.log("----- Account Data After Supply -----");
        console2.log("Total Collateral (USD):", totalCollateralBase);
        console2.log("Total Debt (USD):", totalDebtBase);
        console2.log("Available Borrows (USD):", availableBorrowsBase);
        console2.log("Current Liquidation Threshold:", currentLiquidationThreshold);
        console2.log("LTV:", ltv);
        console2.log("Health Factor:", healthFactor);
        
        // Don't attempt to borrow if no borrowing power
        if (availableBorrowsBase == 0) {
            console2.log("No borrowing power available");
            vm.stopBroadcast();
            return;
        }
        
        // Calculate borrow amount (0.5% of available borrows to be safe)
        uint256 borrowPercentage = 5; // 0.5%
        uint256 borrowAmount = (availableBorrowsBase * borrowPercentage * (10 ** usdcDecimals)) / (1000 * 100);
        
        // Set minimum and maximum borrow amounts
        uint256 minBorrowAmount = 10 ** (usdcDecimals - 4); // 0.0001 USDC
        uint256 maxBorrowAmount = 10 ** (usdcDecimals - 1); // 0.1 USDC
        
        // Ensure borrow amount is within reasonable limits
        borrowAmount = borrowAmount < minBorrowAmount ? minBorrowAmount : borrowAmount;
        borrowAmount = borrowAmount > maxBorrowAmount ? maxBorrowAmount : borrowAmount;
        
        console2.log("Attempting to borrow USDC amount:", borrowAmount / (10 ** usdcDecimals));
        
        // Try to borrow USDC
        try aavePool.borrow(USDC, borrowAmount, 2, 0, user) {
            console2.log("Successfully borrowed USDC");
            
            // Check account data after borrowing
            (
                totalCollateralBase,
                totalDebtBase,
                availableBorrowsBase,
                currentLiquidationThreshold,
                ltv,
                healthFactor
            ) = aavePool.getUserAccountData(user);
            
            console2.log("----- Account Data After Borrow -----");
            console2.log("Total Collateral (USD):", totalCollateralBase);
            console2.log("Total Debt (USD):", totalDebtBase);
            console2.log("Available Borrows (USD):", availableBorrowsBase);
            console2.log("Current Liquidation Threshold:", currentLiquidationThreshold);
            console2.log("LTV:", ltv);
            console2.log("Health Factor:", healthFactor);
        } catch (bytes memory reason) {
            console2.log("Borrowing failed");
            
            // Check if error is due to arithmetic overflow (0x11)
            if (reason.length > 0 && reason[0] == 0x11) {
                console2.log("Arithmetic overflow error detected");
            } 
            
            // Print error bytes for debugging
            console2.log("Error code:");
            for (uint i = 0; i < reason.length && i < 4; i++) {
                console2.log(uint8(reason[i]));
            }
        }
        
        vm.stopBroadcast();
    }
} 