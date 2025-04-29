// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * @title DeployCeloMainnet
 * @notice Script to deploy Lendy contracts to Celo mainnet
 */
contract DeployCeloMainnet is Script {
    // Celo mainnet addresses
    address public constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address public constant CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    
    // Need to find the correct addresses provider address for Celo mainnet
    address public constant AAVE_ADDRESSES_PROVIDER = 0x9F7Cf9417D5251C59fE94fB9147feEe1aAd9Cea5;
    
    // Deployed contract addresses (will be filled during deployment)
    address public lendyProtocol;
    address public lendyPositionManager;

    function setUp() public {}

    function run() public {
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
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying from address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Verify AAVE Pool addresses provider
        try IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getPool() returns (address pool) {
            console.log("Verified Aave Pool address from provider:", pool);
            require(pool == AAVE_POOL, "Pool address mismatch");
        } catch {
            console.log("Failed to verify Aave Pool address, using hardcoded value");
        }

        // Deploy Lendy contracts
        console.log("Deploying LendyProtocol...");
        lendyProtocol = address(new LendyProtocol(AAVE_ADDRESSES_PROVIDER));
        console.log("LendyProtocol deployed at:", lendyProtocol);
        
        console.log("Deploying LendyPositionManager...");
        lendyPositionManager = address(new LendyPositionManager(lendyProtocol));
        console.log("LendyPositionManager deployed at:", lendyPositionManager);

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("AAVE Pool:", AAVE_POOL);
        console.log("AAVE Addresses Provider:", AAVE_ADDRESSES_PROVIDER);
        console.log("USDC:", USDC);
        console.log("USDT:", USDT);
        console.log("cUSD:", CUSD);
        console.log("LendyProtocol:", lendyProtocol);
        console.log("LendyPositionManager:", lendyPositionManager);

        vm.stopBroadcast();
    }
} 