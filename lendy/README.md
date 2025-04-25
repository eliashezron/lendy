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

Lendy is a lending and borrowing platform that leverages Aave V3. It provides a simplified interface to interact with Aave's lending and borrowing functions, with additional features for position management.

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

## Deployed Contracts

Lendy has been successfully deployed to the Celo Alfajores testnet. Here are the deployed contract addresses:

### Mock Tokens
- USDC: [0x7262Bfada9f61530119693d532E716D5CD3191eC](https://alfajores.celoscan.io/address/0x7262Bfada9f61530119693d532E716D5CD3191eC)
- WETH: [0xAC166A1B90308cA742Db5b388FFCBdc3E17a186c](https://alfajores.celoscan.io/address/0xAC166A1B90308cA742Db5b388FFCBdc3E17a186c)
- DAI (with Permit): [0x3B346548fbfa74623047B1E199a96576dd156f2e](https://alfajores.celoscan.io/address/0x3B346548fbfa74623047B1E199a96576dd156f2e)

### Mock Aave Contracts
- MockPool: [0x9E650B3B18aB92bbD4e80Fd6467Aa10B904A045e](https://alfajores.celoscan.io/address/0x9E650B3B18aB92bbD4e80Fd6467Aa10B904A045e)
- MockPoolAddressesProvider: [0xc2a61494430F6a99d5f024Ab6E76b1633c7c13c0](https://alfajores.celoscan.io/address/0xc2a61494430F6a99d5f024Ab6E76b1633c7c13c0)

### Core Lendy Contracts
- LendyProtocol: [0x9113f4531aa608D96dEa970f7D9fE42dC9917A4c](https://alfajores.celoscan.io/address/0x9113f4531aa608D96dEa970f7D9fE42dC9917A4c)
- LendyPositionManager: [0x283E260f03f80982d9D3A83A30A574DFF335D563](https://alfajores.celoscan.io/address/0x283E260f03f80982d9D3A83A30A574DFF335D563)

## Deployment and Testing

### Setup .env File

Create a `.env` file with the following variables:
```
# Your private key for deployment (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Celo Alfajores RPC URL
CELO_ALFAJORES_RPC_URL=https://alfajores-forno.celo-testnet.org
```

### Deploy to Celo Alfajores

```shell
$ forge script script/Deploy.s.sol:DeployLendy --rpc-url celo_alfajores --broadcast --verify
```

### Interact with Deployed Contracts

```shell
$ forge script script/Interact.s.sol:InteractLendy --rpc-url celo_alfajores --broadcast
```

Our interaction tests have verified that the following functions work correctly on Celo Alfajores:

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
