## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Lendy Protocol

Lendy Protocol is a DeFi lending protocol built on top of AAVE V3 on the Celo blockchain. It simplifies lending and borrowing operations by providing a streamlined interface for AAVE.

### Key Features

- Supply and borrow assets using Aave V3
- Position management for lending and borrowing
- Support for ERC20 tokens with permit functionality
- Liquidation functionality for unhealthy positions

### New Permit Functions

The protocol now supports `permit` functions for gasless approvals:

- `supplyWithPermit`: Supply assets using EIP-2612 permit
- `repayWithPermit`: Repay debt using EIP-2612 permit
- `liquidatePositionWithPermit`: Liquidate managed positions using EIP-2612 permit
- `addCollateralWithPermit`: Add collateral to a position using EIP-2612 permit
- `repayDebtWithPermit`: Repay position debt using EIP-2612 permit
- `closePositionWithPermit`: Close a position using EIP-2612 permit

These functions eliminate the need for separate approve transactions, making the protocol more gas-efficient for users.

### Security Enhancements

The protocol includes several security enhancements:

- **Arithmetic Underflow Protection**: The liquidation functions include checks to prevent arithmetic underflows when updating position data after liquidation.
- **Flexible Private Key Handling**: The deployment script supports both numeric and hexadecimal private key formats.
- **Safe Token Transfers**: Uses OpenZeppelin's SafeERC20 for all token transfers.

## Known Issues and Workarounds

### AAVE Collateral Errors (Error Code 43)

When using the Lendy Protocol, you may encounter AAVE error code 43 ("NOT_ENOUGH_AVAILABLE_USER_BALANCE") when trying to:
1. Set tokens as collateral
2. Create positions through the Position Manager

### Workarounds

1. **Use small amounts**:
   - Use 0.1 USDT for supply operations
   - Use 0.01 USDC for borrow operations

2. **Use direct functions instead of Position Manager**:
   - Supply and borrow directly through the Lendy Protocol
   - Use the `direct` test function which interacts with AAVE directly

3. **Correct AAVE Pool Address**:
   The correct AAVE Pool address on Celo mainnet is: `0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402`

## Usage

### Testing with the Deploy Script

To deploy and interact with the Lendy Protocol:

```bash
# Supply USDT and set as collateral (recommended)
./deploy.sh celo_mainnet interact supply

# Check collateral status
./deploy.sh celo_mainnet interact collateral

# Create a position (may fail with error 43)
./deploy.sh celo_mainnet interact position

# Borrow USDC directly (recommended)
./deploy.sh celo_mainnet interact borrow

# Interact directly with AAVE (most reliable)
./deploy.sh celo_mainnet interact direct
```

### Manual Testing

To test the protocol directly using Forge:

```bash
# Supply USDT
export TEST_FUNCTION=supply && forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast -vvv

# Borrow USDC
export TEST_FUNCTION=borrow && forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast -vvv

# Direct AAVE interaction (most reliable)
export TEST_FUNCTION=direct && forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast -vvv
```

## Contract Addresses

- **Lendy Protocol**: `0x80A076F99963C3399F12FE114507b54c13f28510`
- **Position Manager**: `0x5a34479FfcAAB729071725515773E68742d43672`
- **AAVE Pool**: `0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402`
- **USDC**: `0xcebA9300f2b948710d2653dD7B07f33A8B32118C`
- **USDT**: `0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e`
- **cUSD**: `0x765DE816845861e75A25fCA122bb6898B8B1282a`

## Deployed Contracts

### Celo Alfajores Testnet
- USDC: [0x7262Bfada9f61530119693d532E716D5CD3191eC](https://alfajores.celoscan.io/address/0x7262Bfada9f61530119693d532E716D5CD3191eC)
- WETH: [0xAC166A1B90308cA742Db5b388FFCBdc3E17a186c](https://alfajores.celoscan.io/address/0xAC166A1B90308cA742Db5b388FFCBdc3E17a186c)
- DAI (with Permit): [0x3B346548fbfa74623047B1E199a96576dd156f2e](https://alfajores.celoscan.io/address/0x3B346548fbfa74623047B1E199a96576dd156f2e)
- MockPool: [0x9E650B3B18aB92bbD4e80Fd6467Aa10B904A045e](https://alfajores.celoscan.io/address/0x9E650B3B18aB92bbD4e80Fd6467Aa10B904A045e)
- MockPoolAddressesProvider: [0xc2a61494430F6a99d5f024Ab6E76b1633c7c13c0](https://alfajores.celoscan.io/address/0xc2a61494430F6a99d5f024Ab6E76b1633c7c13c0)
- LendyProtocol: [0xAe84B9e6dBa48D14f4ec7741666c976C0556A295](https://alfajores.celoscan.io/address/0xAe84B9e6dBa48D14f4ec7741666c976C0556A295)
- LendyPositionManager: [0xA41cC78C1F302A35184dDBE225d5530376cAd254](https://alfajores.celoscan.io/address/0xA41cC78C1F302A35184dDBE225d5530376cAd254)

### Celo Mainnet
The Lendy protocol can also be deployed to Celo mainnet using real tokens:

- USDC: [0xcebA9300f2b948710d2653dD7B07f33A8B32118C](https://celoscan.io/address/0xcebA9300f2b948710d2653dD7B07f33A8B32118C)
- USDT: [0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e](https://celoscan.io/address/0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e)
- cUSD: [0x765DE816845861e75A25fCA122bb6898B8B1282a](https://celoscan.io/address/0x765DE816845861e75A25fCA122bb6898B8B1282a)
- Aave Pool: [0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402](https://celoscan.io/address/0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402)
- LendyProtocol: [To be deployed]
- LendyPositionManager: [To be deployed]

## Deployment and Testing

### Setup .env File

Create a `.env` file with the following variables:
```
# Your private key for deployment (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Celo Alfajores RPC URL
CELO_ALFAJORES_RPC_URL=https://alfajores-forno.celo-testnet.org

# Celo Mainnet RPC URL
CELO_MAINNET_RPC_URL=https://forno.celo.org

# Celoscan API key 
CELO_API_KEY=your_celoscan_api_key_here
```

### Deploy to Celo Alfajores

```shell
$ forge script script/Deploy.s.sol:DeployLendy --rpc-url celo_alfajores --broadcast --verify
```

### Deploy to Celo Mainnet

```shell
$ forge script script/DeployCeloMainnet.s.sol:DeployCeloMainnet --rpc-url celo_mainnet --broadcast --verify
```

You can also use the helper script for a complete deployment and interaction:

```shell
$ ./deploy.sh celo_mainnet
```

### Interact with Deployed Contracts on Alfajores

```shell
$ forge script script/Interact.s.sol:InteractLendy --rpc-url celo_alfajores --broadcast
```

### Interact with Deployed Contracts on Mainnet

After deployment, you can interact with the contracts using a small amount of tokens (< $0.5):

```shell
$ forge script script/InteractCeloMainnet.s.sol --sig "constructor(address,address)" <LENDY_PROTOCOL_ADDRESS> <LENDY_POSITION_MANAGER_ADDRESS> --rpc-url celo_mainnet --broadcast
```

Our interaction tests verify the following functions:

1. Basic functionality (supply, borrow)
2. Permit functions (supplyWithPermit, repayWithPermit)
3. Position creation and management
4. Liquidation protection against arithmetic underflows

## Local Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
