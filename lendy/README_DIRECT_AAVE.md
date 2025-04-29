# Direct Aave Integration for Lendy

This document provides instructions on deploying and testing the LendyPositionManager with direct Aave Pool integration (without the LendyProtocol wrapper).

## Overview

The LendyPositionManager has been refactored to interact directly with Aave's Pool contract, eliminating the intermediary LendyProtocol contract. This simplifies the architecture, reduces gas costs, and improves error handling.

## Deployment and Testing on Testnet

### Prerequisites

1. Make sure you have Foundry installed:
   ```
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Set your private key as an environment variable:
   ```
   export PRIVATE_KEY=your_private_key_here
   ```

### Deploying Contracts

1. Deploy the modified LendyPositionManager and mock contracts:
   ```
   forge script script/DeployTestnetDirect.s.sol:DeployLendyDirect --rpc-url <testnet_rpc_url> --broadcast
   ```

   This script will:
   - Deploy mock ERC20 tokens (USDC, WETH, DAI)
   - Deploy mock Aave Pool and PoolAddressesProvider
   - Deploy the LendyPositionManager
   - Mint initial token balances for testing
   - Save the deployment addresses to a JSON file for later use

2. The deployment will output addresses to the console and save them to `deployment_addresses.json`.

### Running Tests

The test script allows testing each function individually or running all tests in sequence:

1. To test all functions:
   ```
   forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   ```

2. To test specific functions, set the TEST_FUNCTION environment variable:
   ```
   # Test creating a position
   TEST_FUNCTION=create forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test adding collateral
   TEST_FUNCTION=add forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test withdrawing collateral
   TEST_FUNCTION=withdraw forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test increasing borrow amount
   TEST_FUNCTION=borrow forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test repaying debt
   TEST_FUNCTION=repay forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test closing a position
   TEST_FUNCTION=close forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   
   # Test liquidation
   TEST_FUNCTION=liquidate forge script script/TestDirectInteraction.s.sol:TestDirectInteraction --rpc-url <testnet_rpc_url> --broadcast
   ```

## Deploying to Mainnet

After confirming the contract works as expected on testnet, you can deploy to mainnet by updating the RPC URL:

```
forge script script/DeployLendyDirectMainnet.s.sol:DeployLendyDirectMainnet --rpc-url <mainnet_rpc_url> --broadcast
```

Note: You'll need to create a mainnet deployment script that uses the actual Aave Pool address instead of the mock.

## Advantages of Direct Integration

1. **Reduced Gas Costs**: Eliminating the intermediary contract reduces gas consumption by removing a layer of contract calls.

2. **Simplified Architecture**: Direct integration removes a layer of complexity, making the codebase more maintainable.

3. **Better Error Handling**: Errors from Aave are directly exposed, making debugging and error handling more straightforward.

4. **Streamlined Operations**: Code paths are simpler with fewer fallbacks needed.

5. **Enhanced Security**: Fewer contracts means a smaller attack surface.

## Function Overview

The LendyPositionManager provides the following functionality:

- **createPosition**: Create a new lending and borrowing position
- **addCollateral**: Add collateral to an existing position
- **withdrawCollateral**: Withdraw collateral from an existing position
- **increaseBorrow**: Increase the borrowed amount for a position
- **repayDebt**: Repay debt for a position
- **closePosition**: Close a position by repaying all debt and withdrawing all collateral
- **liquidatePosition**: Liquidate an unhealthy position

Each function interacts directly with Aave's Pool contract, simplifying the codebase while maintaining the same user experience. 