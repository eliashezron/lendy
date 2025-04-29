// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployCeloMainnetV2
 * @notice Script to deploy updated versions of Lendy contracts to Celo mainnet
 * @dev Uses the improved LendyProtocol and LendyPositionManager contracts with fallback mechanisms
 */
contract DeployCeloMainnetV2 is Script {
    // Deployed contract addresses
    address public lendyProtocol;
    address public lendyPositionManager;
    
    // Celo mainnet addresses
    address public constant AAVE_ADDRESSES_PROVIDER = 0x1D91b88E9d9468862a3C0083C129c833c0799811;
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;

    function setUp() public {}

    function run() public {
        // Start broadcasting transactions
        uint256 deployerPrivateKey;
        try vm.envUint("CELO_MAINNET_PRIVATE_KEY") returns (uint256 pk) {
            deployerPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("CELO_MAINNET_PRIVATE_KEY");
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

        // Deploy LendyProtocol 
        console.log("Deploying LendyProtocol with Aave Addresses Provider:", AAVE_ADDRESSES_PROVIDER);
        LendyProtocol protocol = new LendyProtocol(AAVE_ADDRESSES_PROVIDER);
        lendyProtocol = address(protocol);
        console.log("LendyProtocol deployed at:", lendyProtocol);

        // Deploy LendyPositionManager
        console.log("Deploying LendyPositionManager with LendyProtocol:", lendyProtocol);
        LendyPositionManager positionManager = new LendyPositionManager(lendyProtocol);
        lendyPositionManager = address(positionManager);
        console.log("LendyPositionManager deployed at:", lendyPositionManager);

        // Supply some tokens to LendyProtocol to enable setUserUseReserveAsCollateral functionality
        // This is important to fix the UNDERLYING_BALANCE_ZERO issue (error code 43)
        console.log("Checking USDT balance...");
        uint256 usdtBalance = IERC20(USDT).balanceOf(deployer);
        console.log("Deployer's USDT balance:", usdtBalance);
        
        // If the deployer has enough USDT, supply some to the LendyProtocol
        uint256 protocolSupplyAmount = 50000; // 0.05 USDT (with 6 decimals)
        if (usdtBalance >= protocolSupplyAmount) {
            console.log("Supplying", protocolSupplyAmount, "USDT to LendyProtocol");
            
            // Approve and supply USDT for the protocol itself
            IERC20(USDT).approve(lendyProtocol, protocolSupplyAmount);
            protocol.supplyForProtocol(USDT, protocolSupplyAmount);
            
            console.log("Successfully supplied USDT to LendyProtocol");
        } else {
            console.log("Not enough USDT for protocol supply. Need at least 0.05 USDT");
        }
        
        // For USDC as well if available
        console.log("Checking USDC balance...");
        uint256 usdcBalance = IERC20(USDC).balanceOf(deployer);
        console.log("Deployer's USDC balance:", usdcBalance);
        
        if (usdcBalance >= protocolSupplyAmount) {
            console.log("Supplying", protocolSupplyAmount, "USDC to LendyProtocol");
            
            // Approve and supply USDC for the protocol itself
            IERC20(USDC).approve(lendyProtocol, protocolSupplyAmount);
            protocol.supplyForProtocol(USDC, protocolSupplyAmount);
            
            console.log("Successfully supplied USDC to LendyProtocol");
        } else {
            console.log("Not enough USDC for protocol supply");
        }

        // Transfer ownership of the contracts to a multi-sig or other address if needed
        // Can be uncommented and configured as needed
        // address multisig = ADDRESS_HERE;
        // protocol.transferOwnership(multisig);
        // positionManager.transferOwnership(multisig);
        // console.log("Transferred ownership to:", multisig);

        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("LendyProtocol: ", lendyProtocol);
        console.log("LendyPositionManager: ", lendyPositionManager);
        console.log("Aave Addresses Provider: ", AAVE_ADDRESSES_PROVIDER);
        console.log("\nTo interact with these contracts, set these environment variables:");
        console.log("export LENDY_PROTOCOL=", lendyProtocol);
        console.log("export LENDY_POSITION_MANAGER=", lendyPositionManager);
    }
} 