// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManagerSingleton} from "../src/LendyPositionManagerSingleton.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployLendyPositionManager
 * @notice Script to deploy the LendyPositionManager contract directly with the Aave Pool address
 */
contract DeployLendyPositionManagerSingleton is Script {
    // Deployed contract address
    address public lendyPositionManager;
    
    // Celo mainnet addresses
    address public constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    address public constant AAVE_ADDRESSES_PROVIDER = 0x9F7Cf9417D5251C59fE94fB9147feEe1aAd9Cea5;
    
    // Commonly used tokens on Celo
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;

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
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LendyPositionManager directly with the Aave Pool address
        console.log("Deploying LendyPositionManager with Aave Pool:", AAVE_POOL);
        LendyPositionManagerSingleton positionManager = new LendyPositionManagerSingleton(AAVE_POOL);
        lendyPositionManager = address(positionManager);
        console.log("LendyPositionManager deployed at:", lendyPositionManager);

        // Check if we should supply initial tokens to enable setUserUseReserveAsCollateral functionality
        // This is sometimes necessary to initialize Aave's internal state for the contract
        bool supplyInitialTokens = vm.envOr("SUPPLY_INITIAL_TOKENS", false);
        if (supplyInitialTokens) {
            console.log("Checking USDT balance for initial supply...");
            uint256 usdtBalance = IERC20(USDT).balanceOf(deployer);
            console.log("Deployer's USDT balance:", usdtBalance);
            
            // Supply a small amount of USDT if available
            uint256 initialSupplyAmount = 10000; // 0.01 USDT (with 6 decimals)
            if (usdtBalance >= initialSupplyAmount) {
                console.log("Approving and transferring", initialSupplyAmount, "USDT to position manager");
                IERC20(USDT).approve(lendyPositionManager, initialSupplyAmount);
                IERC20(USDT).transfer(lendyPositionManager, initialSupplyAmount);
                console.log("Successfully supplied initial USDT to position manager");
            } else {
                console.log("Not enough USDT for initial supply. Skipping this step.");
            }
        }

        // Transfer ownership of the contract to a multi-sig or other address if specified
        string memory ownerAddressStr = vm.envOr("OWNER_ADDRESS", string(""));
        if (bytes(ownerAddressStr).length > 0) {
            address newOwner = vm.parseAddress(ownerAddressStr);
            console.log("Transferring ownership to:", newOwner);
            positionManager.transferOwnership(newOwner);
        }

        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("LendyPositionManager: ", lendyPositionManager);
        console.log("Aave Pool: ", AAVE_POOL);
        console.log("Aave Addresses Provider: ", AAVE_ADDRESSES_PROVIDER);
        console.log("\nTo interact with this contract, set this environment variable:");
        console.log("export LENDY_POSITION_MANAGER=", lendyPositionManager);
    }
} 