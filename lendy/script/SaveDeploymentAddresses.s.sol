// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title SaveDeploymentAddresses
 * @notice Helper script to save deployment addresses to a JSON file for test scripts
 * @dev This script should be run after deployment to capture contract addresses
 */
contract SaveDeploymentAddresses is Script {
    function saveAddresses(
        address mockPool,
        address mockPoolAddressesProvider,
        address lendyPositionManager,
        address usdc,
        address weth,
        address dai
    ) public {
        // Create a JSON object with the addresses
        string memory json = string(abi.encodePacked(
            "{\n",
            '  "mockPool": "', vm.toString(mockPool), '",\n',
            '  "mockPoolAddressesProvider": "', vm.toString(mockPoolAddressesProvider), '",\n',
            '  "lendyPositionManager": "', vm.toString(lendyPositionManager), '",\n',
            '  "usdc": "', vm.toString(usdc), '",\n',
            '  "weth": "', vm.toString(weth), '",\n',
            '  "dai": "', vm.toString(dai), '"\n',
            "}"
        ));
        
        // Write the JSON to a file
        vm.writeFile("deployment_addresses.json", json);
        console.log("Deployment addresses saved to deployment_addresses.json");
    }
    
    function run() public {
        // Read environment variables for the addresses
        address mockPool = vm.envAddress("MOCK_POOL");
        address mockPoolAddressesProvider = vm.envAddress("MOCK_ADDRESSES_PROVIDER");
        address lendyPositionManager = vm.envAddress("LENDY_POSITION_MANAGER");
        address usdc = vm.envAddress("USDC");
        address weth = vm.envAddress("WETH");
        address dai = vm.envAddress("DAI");
        
        saveAddresses(
            mockPool,
            mockPoolAddressesProvider,
            lendyPositionManager,
            usdc,
            weth,
            dai
        );
    }
} 