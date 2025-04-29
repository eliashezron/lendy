// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockPool} from "../test/mocks/MockPool.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";

/**
 * @title TestWithHardcodedKey
 * @notice Simple test script with hardcoded key and addresses
 */
contract TestWithHardcodedKey is Script {
    // IMPORTANT: This is a test private key with no real value
    // DO NOT USE THIS KEY FOR ANYTHING REAL
    uint256 constant TEST_PRIVATE_KEY = 0xPRIVATEKEY;
    
    // Hardcoded addresses from deployment output
    address public constant POSITION_MANAGER = 0x1ab49E36A37Ac3aAf4a74dF72cC4Bea885a10D27;
    address public constant MOCK_POOL = 0x4e1787BA6f424Cd199A119178c2324fAAA8c6519;
    address public constant USDC = 0x18ed4EF6B2d83b96946B6a8cc7aFd9A66139492b;
    address public constant WETH = 0x2BA06586323e0f5490Bf2b1AbE039399e87fEf73;
    address public constant DAI = 0x49135859F47505D97035a49940c20d704142A8D2;

    function setUp() public {}

    function run() public {
        // Get test user address from the key
        address testUser = vm.addr(TEST_PRIVATE_KEY);
        
        console.log("Running test with hardcoded key...");
        console.log("Test user address:", testUser);
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Mock Pool:", MOCK_POOL);
        
        // Start broadcasting with the test key
        vm.startBroadcast(TEST_PRIVATE_KEY);
        
        // Try to read contract info
        console.log("\n=== Testing Contract Access ===");
        
        // Check if we can access token contracts
        try MockERC20(USDC).symbol() returns (string memory symbol) {
            console.log("USDC symbol:", symbol);
        } catch {
            console.log("Failed to access USDC token");
        }
        
        try MockERC20(WETH).symbol() returns (string memory symbol) {
            console.log("WETH symbol:", symbol);
        } catch {
            console.log("Failed to access WETH token");
        }
        
        // Check if the contracts have owners and if we can mint tokens
        console.log("\n=== Testing Token Minting ===");
        
        // Try to mint WETH to our test user
        try MockERC20(WETH).mint(testUser, 1 ether) {
            console.log("Successfully minted 1 WETH to test user");
            
            // Check the balance
            uint256 balance = IERC20(WETH).balanceOf(testUser);
            console.log("New WETH balance:", balance);
        } catch {
            console.log("Failed to mint WETH - check if contract is accessible and if the account has minter role");
        }
        
        // Check if we can access the position manager
        console.log("\n=== Testing Position Manager ===");
        
        try LendyPositionManager(POSITION_MANAGER).POOL() returns (IPool pool) {
            console.log("Position Manager's POOL address:", address(pool));
        } catch {
            console.log("Failed to access Position Manager");
        }
        
        vm.stopBroadcast();
    }
} 