// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestInteraction
 * @notice Script to demonstrate interaction format for Lendy contracts on Celo mainnet
 */
contract TestInteraction is Script {
    // Contract addresses
    address public constant LENDY_PROTOCOL = 0x80A076F99963C3399F12FE114507b54c13f28510;
    address public constant LENDY_POSITION_MANAGER = 0x5a34479FfcAAB729071725515773E68742d43672;
    
    // Celo mainnet token addresses
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    
    // Test variables
    LendyProtocol public lendyProtocol;
    LendyPositionManager public positionManager;
    address public testUser;
    uint256 public testPrivateKey;
    
    // NOTE: NEVER use a hardcoded private key in production!
    // This is ONLY for demonstration purposes
    uint256 constant DEMO_PRIVATE_KEY = 0x1234; // NOT A REAL KEY

    function setUp() public {
        // Use a test private key for demonstration
        testPrivateKey = DEMO_PRIVATE_KEY;
        testUser = vm.addr(testPrivateKey);
        
        // Initialize contracts
        lendyProtocol = LendyProtocol(LENDY_PROTOCOL);
        positionManager = LendyPositionManager(LENDY_POSITION_MANAGER);
    }

    function run() public {
        console.log("Running test interaction script...");
        console.log("LENDY_PROTOCOL address:", LENDY_PROTOCOL);
        console.log("LENDY_POSITION_MANAGER address:", LENDY_POSITION_MANAGER);
        console.log("Test user address:", testUser);
        
        // IMPORTANT: In a real scenario, you would use:
        // TEST_FUNCTION=all forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet \
        //   --rpc-url https://forno.celo.org \
        //   --broadcast \
        //   --private-key $CELO_MAINNET_PRIVATE_KEY
        
        // This is just a demonstration script
        console.log("\nTo run the real script, use:");
        console.log("TEST_FUNCTION=all forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast --private-key YOUR_PRIVATE_KEY");
        console.log("\nAvailable TEST_FUNCTION values:");
        console.log("- supply: Test supplying USDT as collateral");
        console.log("- collateral: Test checking collateral info");
        console.log("- position: Test creating a position with USDT as collateral to borrow USDC");
        console.log("- borrow: Test direct borrowing USDC");
        console.log("- all: Run all tests");
    }
} 