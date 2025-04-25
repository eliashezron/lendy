# Lendy - Celo Testnet Deployment Guide

This guide explains how to deploy and test the Lendy protocol on the Celo Alfajores testnet.

## Prerequisites

1. **Install Foundry**: Make sure you have Foundry installed. If not, follow the instructions [here](https://book.getfoundry.sh/getting-started/installation).

2. **Setup Wallet**: You need a wallet with some testnet CELO tokens for gas.

3. **Get Testnet Tokens**: You can get testnet CELO from the [Celo Faucet](https://faucet.celo.org/).

## Environment Setup

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd lendy
   ```

2. **Install dependencies**:
   ```bash
   forge install
   ```

3. **Create your .env file**:
   ```bash
   cp .env-example .env
   ```

4. **Fill in your environment variables** in the `.env` file:
   ```
   PRIVATE_KEY=your_private_key_without_0x_prefix
   CELO_ALFAJORES_RPC_URL=https://alfajores-forno.celo-testnet.org
   CELO_API_KEY=your_celoscan_api_key_if_you_have_one
   ```

## Deployment

1. **Load environment variables**:
   ```bash
   source .env
   ```

2. **Deploy the contracts**:
   ```bash
   forge script script/Deploy.s.sol:DeployLendy --rpc-url $CELO_ALFAJORES_RPC_URL --broadcast --verify
   ```

3. **Record contract addresses**: After deployment, note the addresses of the deployed contracts:
   - LendyProtocol
   - LendyPositionManager
   - USDC (mock)
   - WETH (mock)
   - DAI (mock)
   - MockPool
   - MockPoolAddressesProvider

## Interacting with Deployed Contracts

1. **Update the interaction script** with the actual contract addresses:
   Edit the `script/Interact.s.sol` file and update these constants:
   ```solidity
   address public constant LENDY_PROTOCOL = address(0); // Replace with actual address
   address public constant LENDY_POSITION_MANAGER = address(0); // Replace with actual address
   address public constant USDC = address(0); // Replace with actual address
   address public constant WETH = address(0); // Replace with actual address
   ```

2. **Run the interaction script**:
   ```bash
   forge script script/Interact.s.sol:InteractLendy --rpc-url $CELO_ALFAJORES_RPC_URL --broadcast
   ```

## Testing on Celo Testnet

The interaction script demonstrates basic functionality:

1. Supplying WETH as collateral
2. Borrowing USDC
3. Creating a position in the position manager
4. Checking position details

## Verifying Contract Deployment

You can verify that the contracts were deployed correctly by:

1. Checking the transaction on [Celoscan Alfajores](https://alfajores.celoscan.io/)
2. Interacting with the contracts using the provided scripts
3. Using a wallet like Metamask connected to Celo Alfajores to interact with the contracts

## Common Issues

1. **Insufficient Gas**: Make sure you have enough testnet CELO in your wallet.
2. **Transaction Failure**: If transactions fail, check the revert reason in the forge output or on Celoscan.
3. **Contract Verification Failure**: If verification fails, you may need to flatten your contracts or verify manually.

## Notes for Production Deployment

For a production deployment, you would:

1. Use actual Aave V3 pool contracts instead of mocks
2. Deploy to Celo mainnet after thorough testing and auditing
3. Ensure proper security measures are in place for private keys and contract ownership 