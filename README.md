# Lendy - Lending and Borrowing Platform

Lendy is a smart contract platform that leverages Aave V3 contracts to provide simple lending and borrowing functionality. It serves as a wrapper around Aave V3, making it easier for users to manage their positions.

## Key Features

- Supply assets to earn interest via Aave V3
- Borrow assets against your supplied collateral
- Manage lending and borrowing positions through a simple interface
- Track user positions and health factors

## Architecture

The platform consists of two main contracts:

1. `LendyProtocol.sol` - Core contract that interfaces directly with Aave V3 Pool
2. `LendyPositionManager.sol` - Contract for managing user lending and borrowing positions

## Development

Lendy is built using Foundry, a modern Ethereum development environment.

### Setup

```bash
git clone https://github.com/yourusername/lendy.git
cd lendy
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/Deploy.s.sol:DeployLendy --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Security Considerations

- Lendy inherits the security model of Aave V3
- The contracts have been designed with security best practices in mind
- Users should be aware of liquidation risks when borrowing assets

## License

This project is licensed under the MIT License.
