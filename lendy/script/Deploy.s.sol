// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {LendyProtocol} from "../src/LendyProtocol.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";

/**
 * @title DeployLendy
 * @notice Script to deploy the Lendy protocol contracts
 */
contract DeployLendy is Script {
    // Address of Aave PoolAddressesProvider on different networks
    // Addresses from: https://docs.aave.com/developers/deployed-contracts/v3-mainnet/polygon
    address constant POOL_ADDRESSES_PROVIDER_POLYGON = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POOL_ADDRESSES_PROVIDER_AVALANCHE = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POOL_ADDRESSES_PROVIDER_ARBITRUM = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POOL_ADDRESSES_PROVIDER_OPTIMISM = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POOL_ADDRESSES_PROVIDER_FANTOM = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant POOL_ADDRESSES_PROVIDER_ETHEREUM = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Detect chain and select the right PoolAddressesProvider
        uint256 chainId = block.chainid;
        address poolAddressesProvider;

        if (chainId == 1) {
            // Ethereum Mainnet
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_ETHEREUM;
        } else if (chainId == 137) {
            // Polygon
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_POLYGON;
        } else if (chainId == 43114) {
            // Avalanche
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_AVALANCHE;
        } else if (chainId == 42161) {
            // Arbitrum
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_ARBITRUM;
        } else if (chainId == 10) {
            // Optimism
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_OPTIMISM;
        } else if (chainId == 250) {
            // Fantom
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_FANTOM;
        } else {
            // Default to Ethereum for local testing, you would replace this in a real deployment
            poolAddressesProvider = POOL_ADDRESSES_PROVIDER_ETHEREUM;
        }

        // Deploy LendyProtocol
        LendyProtocol lendyProtocol = new LendyProtocol(poolAddressesProvider);
        
        // Deploy LendyPositionManager
        LendyPositionManager positionManager = new LendyPositionManager(address(lendyProtocol));

        // Log the deployed addresses
        console.log("LendyProtocol deployed at: ", address(lendyProtocol));
        console.log("LendyPositionManager deployed at: ", address(positionManager));

        vm.stopBroadcast();
    }
} 