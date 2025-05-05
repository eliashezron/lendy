# Lendy - DeFi Lending Platform on Celo

Lendy is a decentralized finance (DeFi) platform built on the Celo blockchain that simplifies the lending and borrowing experience. By leveraging Aave V3 protocol under the hood, Lendy provides a streamlined interface for users to supply assets, borrow against their collateral, and manage their positions through an intuitive user interface.

## Live Demo

- **Web Application**: [https://lendy-silk.vercel.app/](https://lendy-silk.vercel.app/)
- **Video Demo**: [Watch on YouTube](https://youtu.be/MaBM4kO2IHM)
- **Mainnet Contract**: `0xC0EF6c32504802d05a0Fc3078866DaF9BaBeE879`

## Key Features

- **Supply to Earn**: Deposit stablecoins (USDC, USDT) to earn interest on your assets
- **Collateralized Borrowing**: Use your supplied assets as collateral to borrow other assets
- **Position Management**: Easily track, modify, and close your lending and borrowing positions
- **Streamlined User Experience**: Simplified interface compared to direct Aave interaction
- **MiniPay Compatible**: Fully functional with Celo's MiniPay wallet

## Architecture

The platform consists of two main components:

### Smart Contracts

1. **LendyPositionManagerSingleton.sol** - Central contract that:
   - Manages user lending and borrowing positions
   - Interfaces with Aave's Pool contract
   - Handles position creation, modification, and closure
   - Tracks all user positions with a unique ID system

2. **Key Contract Features**:
   - Position management with automatic collateral and debt tracking
   - Supply-only functionality for users who just want to earn interest
   - Health factor monitoring to prevent liquidations
   - Collateral addition, withdrawal, and debt management

### Frontend Application

Built with Next.js and React, featuring:
- **Wallet Integration**: Connect with Celo wallets including MiniPay
- **Position Dashboard**: View and manage all your positions in one place
- **Supply Flow**: Simple interface to supply assets and earn interest
- **Borrow Flow**: Intuitive UI for creating collateralized loans

## Contract Functions

### Supply Operations
- `supply(address asset, uint256 amount)`: Create a supply-only position
- `increaseSupply(uint256 supplyPositionId, uint256 additionalAmount)`: Add to an existing supply position
- `withdrawSupply(uint256 supplyPositionId, uint256 withdrawAmount)`: Withdraw part of a supply position
- `closeSupplyPosition(uint256 supplyPositionId)`: Close a supply position entirely

### Borrowing Operations
- `createPosition(address collateralAsset, uint256 collateralAmount, address borrowAsset, uint256 borrowAmount, uint256 interestRateMode)`: Create a borrowing position
- `addCollateral(uint256 positionId, uint256 additionalAmount)`: Add more collateral to a position
- `withdrawCollateral(uint256 positionId, uint256 withdrawAmount)`: Withdraw collateral from a position
- `increaseBorrow(uint256 positionId, uint256 additionalBorrowAmount)`: Borrow more against existing collateral
- `repayDebt(uint256 positionId, uint256 amount)`: Repay borrowed debt
- `closePosition(uint256 positionId)`: Close a borrowing position

### View Functions
- `getUserPositions(address user)`: Get all borrowing positions for a user
- `getUserSupplyPositions(address user)`: Get all supply positions for a user
- `getPositionDetails(uint256 positionId)`: Get detailed information about a borrowing position
- `getSupplyPositionDetails(uint256 supplyPositionId)`: Get detailed information about a supply position
- `getHealthFactor()`: Get the contract's current health factor

## User Flows

### Earning Interest
1. Connect wallet
2. Select token (USDC/USDT)
3. Enter amount to supply
4. Confirm transaction
5. Monitor earnings in the Positions page

### Borrowing Assets
1. Connect wallet
2. Enter collateral amount and asset
3. Select borrow amount and asset
4. Review position details including health factor
5. Confirm transaction
6. Manage position from the Positions page

### Managing Positions
- Add collateral to improve health factor
- Withdraw available collateral
- Repay debt partially or in full
- Monitor interest accrual on both supply and borrow sides

## Development

### Setup and Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/lendy.git
cd lendy

# Install dependencies
# For smart contracts
forge install

# For frontend
cd frontend
npm install
```

### Running the Frontend

```bash
cd frontend
npm run dev
```

### Smart Contract Deployment

```bash
forge script script/Deploy.s.sol:DeployLendy --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Security Considerations

- Lendy inherits the security model of Aave V3
- User positions are isolated and tracked independently
- Health factor monitoring helps prevent liquidations
- Administrative functions are protected by ownership checks
- The platform has been designed with security best practices in mind

## Future Enhancements

- Support for additional assets beyond stablecoins
- Integrated DEX for one-click token swaps
- Leverage features for advanced users
- Mobile app integration
- Multi-chain support

## License

This project is licensed under the MIT License.
