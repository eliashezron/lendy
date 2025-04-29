// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";

/**
 * @title DeployLendyDirectMainnet
 * @notice Script to deploy the direct LendyPositionManager contract to mainnet
 * @dev This deploys the LendyPositionManager that directly interacts with Aave's Pool
 */
contract DeployLendyDirectMainnet is Script {
    // Deployed contract addresses
    address public lendyPositionManager;
    
    // Aave Pool addresses on different networks
    // Source: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/polygon
    mapping(uint256 => address) public poolAddresses;
    
    function setUp() public {
        // Set up Aave Pool addresses for different networks
        // poolAddresses[1] = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Ethereum Mainnet
        // poolAddresses[137] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Polygon
        // poolAddresses[42161] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Arbitrum
        // poolAddresses[43114] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Avalanche
        // poolAddresses[10] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Optimism
        poolAddresses[42220] = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402; // Celo
    }

    function run() public {
        // Get the chain ID to determine which Aave Pool address to use
        uint256 chainId = block.chainid;
        address poolAddress = poolAddresses[chainId];
        
        if (poolAddress == address(0)) {
            revert("Aave Pool address not configured for this network");
        }
        
        console.log("Deploying to chain ID:", chainId);
        console.log("Using Aave Pool address:", poolAddress);
        
        // Start broadcasting transactions
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            deployerPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("PRIVATE_KEY");
            if (bytes(pkString).length > 0 && bytes(pkString)[0] == "0" && bytes(pkString)[1] == "x") {
                deployerPrivateKey = vm.parseUint(pkString);
            } else {
                // If no 0x prefix, try adding it
                deployerPrivateKey = vm.parseUint(string(abi.encodePacked("0x", pkString)));
            }
        }
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LendyPositionManager (directly interacting with Aave Pool)
        lendyPositionManager = address(new LendyPositionManager(poolAddress));

        console.log("LendyPositionManager deployed at:", lendyPositionManager);

        vm.stopBroadcast();
        
        // Save address to environment variable for easier access in other scripts
        vm.setEnv("LENDY_POSITION_MANAGER", vm.toString(lendyPositionManager));
        
        // Print deployment info to console instead of writing to file
        console.log("\nDeployment Information:");
        console.log("=======================");
        console.log("LendyPositionManager:", lendyPositionManager);
        console.log("Aave Pool:          ", poolAddress);
        console.log("=======================");
        console.log("\nCopy these addresses for interacting with the contracts");
    }
} 