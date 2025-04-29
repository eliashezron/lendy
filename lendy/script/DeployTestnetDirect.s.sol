// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendyPositionManager} from "../src/LendyPositionManager.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockERC20Permit} from "../test/mocks/MockERC20Permit.sol";
import {MockPoolAddressesProvider} from "../test/mocks/MockPoolAddressesProvider.sol";
import {MockPool} from "../test/mocks/MockPool.sol";
import {SaveDeploymentAddresses} from "./SaveDeploymentAddresses.s.sol";

/**
 * @title DeployLendyDirect
 * @notice Script to deploy the direct LendyPositionManager contract to testnet
 * @dev This deploys mocks for testing and the LendyPositionManager that directly interacts with Aave's Pool
 */
contract DeployLendyDirect is Script {
    // Deployed contract addresses
    address public mockPool;
    address public mockPoolAddressesProvider;
    address public lendyPositionManager;
    address public usdc;
    address public weth;
    address public dai;

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
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens 
        usdc = address(new MockERC20("USD Coin", "USDC", 6));
        weth = address(new MockERC20("Wrapped Ether", "WETH", 18));
        dai = address(new MockERC20Permit("Dai Stablecoin", "DAI", 18));

        console.log("USDC deployed at:", usdc);
        console.log("WETH deployed at:", weth);
        console.log("DAI deployed at:", dai);

        // Deploy mock Aave contracts
        mockPool = address(new MockPool());
        mockPoolAddressesProvider = address(new MockPoolAddressesProvider());
        MockPoolAddressesProvider(mockPoolAddressesProvider).setPool(mockPool);

        console.log("MockPool deployed at:", mockPool);
        console.log("MockPoolAddressesProvider deployed at:", mockPoolAddressesProvider);

        // Deploy LendyPositionManager (directly interacting with Aave Pool)
        lendyPositionManager = address(new LendyPositionManager(mockPool));

        console.log("LendyPositionManager deployed at:", lendyPositionManager);

        // Mint initial tokens to deployer for testing
        address deployer = vm.addr(deployerPrivateKey);
        uint256 initialBalance = 10000 * 10**18; // 10,000 tokens
        uint256 initialUsdcBalance = 10000 * 10**6; // 10,000 USDC

        MockERC20(usdc).mint(deployer, initialUsdcBalance);
        MockERC20(weth).mint(deployer, initialBalance);
        MockERC20(dai).mint(deployer, initialBalance);

        // Mint tokens to the mock pool for liquidity
        MockERC20(usdc).mint(mockPool, initialUsdcBalance * 10);
        MockERC20(weth).mint(mockPool, initialBalance * 10);
        MockERC20(dai).mint(mockPool, initialBalance * 10);

        vm.stopBroadcast();
        
        // Save deployment addresses to file for test scripts
        SaveDeploymentAddresses saveAddresses = new SaveDeploymentAddresses();
        saveAddresses.saveAddresses(
            mockPool,
            mockPoolAddressesProvider,
            lendyPositionManager,
            usdc,
            weth,
            dai
        );
        
        // Also set environment variables for easier access
        vm.setEnv("MOCK_POOL", vm.toString(mockPool));
        vm.setEnv("MOCK_ADDRESSES_PROVIDER", vm.toString(mockPoolAddressesProvider));
        vm.setEnv("LENDY_POSITION_MANAGER", vm.toString(lendyPositionManager));
        vm.setEnv("USDC", vm.toString(usdc));
        vm.setEnv("WETH", vm.toString(weth));
        vm.setEnv("DAI", vm.toString(dai));
    }
} 